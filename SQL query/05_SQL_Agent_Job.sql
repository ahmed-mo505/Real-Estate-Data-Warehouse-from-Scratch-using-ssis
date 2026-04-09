-- ============================================================
--  SCRIPT 05 — SQL Server Agent Job
--  بيشغّل الـ SSIS Package أوتوماتيك كل يوم الساعة 2 الصبح
-- ============================================================

USE msdb;
GO

-- ─────────────────────────────────────────────
-- Step 1: حذف الـ Job لو موجود (للـ Re-run)
-- ─────────────────────────────────────────────
IF EXISTS (
    SELECT job_id FROM msdb.dbo.sysjobs
    WHERE name = N'RealEstate_DWH_Daily_Load'
)
BEGIN
    EXEC msdb.dbo.sp_delete_job
        @job_name = N'RealEstate_DWH_Daily_Load',
        @delete_unused_schedule = 1;
    PRINT '⚠️  Old job deleted.';
END
GO

-- ─────────────────────────────────────────────
-- Step 2: إنشاء الـ Job
-- ─────────────────────────────────────────────
EXEC msdb.dbo.sp_add_job
    @job_name        = N'RealEstate_DWH_Daily_Load',
    @enabled         = 1,
    @description     = N'Daily ETL: Load CSV + TXT + API into Staging DB',
    @category_name   = N'Data Collector',
    @owner_login_name = N'sa';   -- غيّر ده لـ login بتاعك
GO

-- ─────────────────────────────────────────────
-- Step 3: إضافة الـ Job Steps
-- ─────────────────────────────────────────────

-- Step 3A: Create & Truncate Staging Tables
EXEC msdb.dbo.sp_add_jobstep
    @job_name       = N'RealEstate_DWH_Daily_Load',
    @step_name      = N'01 - Prepare Staging DB',
    @step_id        = 1,
    @subsystem      = N'TSQL',
    @command        = N'
        IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = ''RealEstate_Staging'')
            CREATE DATABASE RealEstate_Staging;

        USE RealEstate_Staging;

        IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = ''STG'')
            EXEC(''CREATE SCHEMA STG'');

        -- Truncate tables if they exist
        IF OBJECT_ID(''STG.STG_Listings'',     ''U'') IS NOT NULL TRUNCATE TABLE STG.STG_Listings;
        IF OBJECT_ID(''STG.STG_Transactions'', ''U'') IS NOT NULL TRUNCATE TABLE STG.STG_Transactions;
        IF OBJECT_ID(''STG.STG_Agents'',       ''U'') IS NOT NULL TRUNCATE TABLE STG.STG_Agents;
        IF OBJECT_ID(''STG.STG_Currency'',     ''U'') IS NOT NULL TRUNCATE TABLE STG.STG_Currency;
        ',
    @database_name  = N'master',
    @on_success_action = 3,   -- 3 = Go to next step
    @on_fail_action    = 2;   -- 2 = Quit with failure
GO

-- Step 3B: Run SSIS Package (Load to Staging)
EXEC msdb.dbo.sp_add_jobstep
    @job_name       = N'RealEstate_DWH_Daily_Load',
    @step_name      = N'02 - Run SSIS Load to Staging',
    @step_id        = 2,
    @subsystem      = N'SSIS',          -- نوع الـ Step = SSIS Package
    @command        = N'
        /FILE "C:\SSIS_Packages\RealEstate_Load_Staging.dtsx"
        /CHECKPOINTING OFF
        /REPORTING EW
        ',
    -- لو Package على SSISDB (Integration Services Catalog):
    -- @subsystem = N'SSIS',
    -- @command   = N'/ISSERVER "\SSISDB\RealEstate\Load_Staging\RealEstate_Load_Staging" /SERVER "." /ENVREFERENCE 1 /Par "$ServerOption::SYNCHRONIZED(Boolean)";True',
    @on_success_action = 3,
    @on_fail_action    = 2;
GO

-- Step 3C: Log completion
EXEC msdb.dbo.sp_add_jobstep
    @job_name       = N'RealEstate_DWH_Daily_Load',
    @step_name      = N'03 - Log Job Completion',
    @step_id        = 3,
    @subsystem      = N'TSQL',
    @command        = N'
        USE RealEstate_Staging;
        INSERT INTO STG.STG_Load_Log
            (package_name, table_name, run_start, run_end, status)
        VALUES
            (''RealEstate_Load_Staging'', ''ALL'',
             DATEADD(MINUTE,-5,GETDATE()), GETDATE(), ''SUCCESS'');
        ',
    @database_name  = N'RealEstate_Staging',
    @on_success_action = 1,   -- 1 = Quit with success
    @on_fail_action    = 2;
GO

-- ─────────────────────────────────────────────
-- Step 4: إنشاء الـ Schedule
-- ─────────────────────────────────────────────
EXEC msdb.dbo.sp_add_schedule
    @schedule_name      = N'Daily_2AM',
    @freq_type          = 4,        -- 4 = Daily
    @freq_interval      = 1,        -- كل يوم
    @active_start_time  = 020000,   -- 02:00:00 AM
    @active_end_time    = 235959;
GO

-- ربط الـ Schedule بالـ Job
EXEC msdb.dbo.sp_attach_schedule
    @job_name       = N'RealEstate_DWH_Daily_Load',
    @schedule_name  = N'Daily_2AM';
GO

-- تحديد الـ Server
EXEC msdb.dbo.sp_add_jobserver
    @job_name       = N'RealEstate_DWH_Daily_Load',
    @server_name    = N'(local)';
GO

PRINT '';
PRINT '═══════════════════════════════════════════════════';
PRINT '✅ SQL Agent Job Created Successfully!';
PRINT '   Job Name : RealEstate_DWH_Daily_Load';
PRINT '   Schedule : Every day at 02:00 AM';
PRINT '   Steps    : 3 (Prepare → SSIS → Log)';
PRINT '═══════════════════════════════════════════════════';
GO
