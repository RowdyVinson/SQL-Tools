/*
################## Dev Server Maintenance Window ##################
############## Friday Weekly Backup/Maintenance only ##############


******Rowdy Vinson 8/29/14******
 For use with Ola Hallengren's SQL MaintenanceSolution. 
 Run after MaintenanceSolution.sql has completed successfully.
 http://ola.hallengren.com/scripts/MaintenanceSolution.sql
 Servers running the schedule must meet the following requirements:

 - Documented as being a Low Backup Frequency server
 - No Full Recovery Mode databases (no log backups scheduled, though retention could be set)
 - Weekly SQL RPO
 - Disk space on V:\ for Full x1

******Rowdy Vinson 2/26/16******
In freq_type = 8 (weekly), 1 = Sunday, 2 = Monday, 4 = Tuesday, 8 = Wednesday, 16 = Thursday, 32 = Friday, 64 = Saturday
freq_interval of 126 means every day EXCEPT Sunday 2+4+8+16+32+64=126 
The range is up to 127 where all days are selected. 
Script pilfered from Ryan Devries
https://github.com/ryandevries/Scripts/blob/master/Powershell/Ola-Deploy/2_Maintenance-Solution/Schedules/Test.sql
*/


-- Dev Schedules
SET NOCOUNT ON
USE msdb
BEGIN
	-- All the variables needed for creating the schedules and adding them to the jobs
	DECLARE @SchOwner      nvarchar(max)
	DECLARE @SchName01     nvarchar(max), @SchName02     nvarchar(max), @SchName03     nvarchar(max), @SchName04     nvarchar(max), @SchName05     nvarchar(max), @SchName06     nvarchar(max), @SchName07     nvarchar(max), @SchName08     nvarchar(max)
	DECLARE @SchFreqType01 int,           @SchFreqType02 int,           @SchFreqType03 int,           @SchFreqType04 int,           @SchFreqType05 int,           @SchFreqType06 int,           @SchFreqType07 int,           @SchFreqType08 int
	DECLARE @SchFreqInt01  int,           @SchFreqInt02  int,           @SchFreqInt03  int,           @SchFreqInt04  int,           @SchFreqInt05  int,           @SchFreqInt06  int,           @SchFreqInt07  int,           @SchFreqInt08  int
	DECLARE @SchSubType01  int,           @SchSubType02  int,           @SchSubType03  int,           @SchSubType04  int,           @SchSubType05  int,           @SchSubType06  int,           @SchSubType07  int,           @SchSubType08  int
	DECLARE @SchSubInt01   int,           @SchSubInt02   int,           @SchSubInt03   int,           @SchSubInt04   int,           @SchSubInt05   int,           @SchSubInt06   int,           @SchSubInt07   int,           @SchSubInt08   int
	DECLARE @SchRelInt01   int,           @SchRelInt02   int,           @SchRelInt03   int,           @SchRelInt04   int,           @SchRelInt05   int,           @SchRelInt06   int,           @SchRelInt07   int,           @SchRelInt08   int
	DECLARE @SchFreqRec01  int,           @SchFreqRec02  int,           @SchFreqRec03  int,           @SchFreqRec04  int,           @SchFreqRec05  int,           @SchFreqRec06  int,           @SchFreqRec07  int,           @SchFreqRec08  int
	DECLARE @SchStart01    int,           @SchStart02    int,           @SchStart03    int,           @SchStart04    int,           @SchStart05    int,           @SchStart06    int,           @SchStart07    int,           @SchStart08    int
	DECLARE @SchEnd01      int,           @SchEnd02      int,           @SchEnd03      int,           @SchEnd04      int,           @SchEnd05      int,           @SchEnd06      int,           @SchEnd07      int,           @SchEnd08      int
	DECLARE @JobName01     nvarchar(max), @JobName02     nvarchar(max), @JobName03     nvarchar(max), @JobName04     nvarchar(max), @JobName05     nvarchar(max), @JobName06     nvarchar(max), @JobName07     nvarchar(max), @JobName08     nvarchar(max), @JobName09 nvarchar(max), @JobName10 nvarchar(max), @JobName11 nvarchar(max)
	-- Job Names
	SET @JobName01 = 'DatabaseBackup - SYSTEM_DATABASES - FULL'
	SET @JobName02 = 'DatabaseBackup - USER_DATABASES - FULL'
--	SET @JobName03 = 'Maintenance - Backups - USER - DIFF' -- Unused here
--	SET @JobName04 = 'Maintenance - Backups - USER - LOG' -- Unused here
	SET @JobName05 = 'IndexOptimize - USER_DATABASES'
	SET @JobName06 = 'DatabaseIntegrityCheck - USER_DATABASES'
	SET @JobName07 = 'DatabaseIntegrityCheck - SYSTEM_DATABASES'
	SET @JobName08 = 'CommandLog Cleanup'
	SET @JobName09 = 'Output File Cleanup'
	SET @JobName10 = 'sp_delete_backuphistory'
	SET @JobName11 = 'sp_purge_jobhistory'
	-- Set SA account as schedule owner
	SET @SchOwner  = SUSER_SNAME(0x01)
	-- Schedule Names
	SET @SchName01 = 'SYSTEM-FULL BACKUPS'
	SET @SchName02 = 'USER-FULL BACKUPS'
--	SET @SchName03 = 'USER-DIFF BACKUPS' -- Unused here
--	SET @SchName04 = 'Test User TLog Backups - Hourly 4AM-12AM'  -- Unused here
	SET @SchName05 = 'Index Maintenance'
	SET @SchName06 = 'Integrity Maintenance'
--	SET @SchName07 = 'Test System CheckDB - Daily 8PM' --Shared with User DBs in Integrity Maintenance job
	SET @SchName08 = 'Cleanup Maintenance'
	-- Frequency Type: 1 = Once, 4 = Daily, 8 = Weekly, 16 = Monthly, 32 = Monthly relativity to freq_interval, 64 = When the agent starts, 128 = When idle
	-- Frequency Interval, depends on freq_type: 
		-- 1  : Unused
		-- 4  : Every specified number of days
		-- 8  : Logical OR, 1 = Sunday, 2 = Monday, 4 = Tuesday, 8 = Wednesday, 16 = Thursday, 32 = Friday, 64 = Saturday
		-- 16 : On the specified day of the month
		-- 32 : 1 = Sunday, 2 = Monday, 3 = Tuesday, 4 = Wednesday, 5 = Thursday, 6 = Friday, 7 = Saturday, 8 = Day, 9 = Weekday, 10 = Weekend day
		-- 64 : Unused
		-- 128: Unused
	-- Frequency Subday Type, units for freq_subday_interval: 1 = At the specified time, 2 = Seconds, 4 = Minutes, 8 = Hours
	-- Frequency Subday Interval, number of freq_subday_type periods to occur between each execution
	-- Frequency Relative Interval, only used for freq_interval of 32: 1 = First, 2 = Second, 4 = Third, 8 = Fourth, 16 = Last
	-- Frequency Recurrence Factor, only used for freq_type of 8, 16, or 32: Number of weeks or months between each execution
	-- Start Time on the 24 hr clock
	-- End Time on the 24 hr clock
	SELECT @SchFreqType01 = 8,      @SchFreqType02 = 8,      @SchFreqType03 = 8,      @SchFreqType04 = 8,      @SchFreqType05 = 8,      @SchFreqType06 = 8,      @SchFreqType07 = 8,      @SchFreqType08 = 8
	SELECT @SchFreqInt01  = 32,     @SchFreqInt02  = 32,     @SchFreqInt03  = 32,     @SchFreqInt04  = 32,     @SchFreqInt05  = 32,     @SchFreqInt06  = 32,     @SchFreqInt07  = 32,     @SchFreqInt08  = 32
	SELECT @SchSubType01  = 1,      @SchSubType02  = 1,      @SchSubType03  = 1,      @SchSubType04  = 8,      @SchSubType05  = 1,      @SchSubType06  = 1,      @SchSubType07  = 1,      @SchSubType08  = 1
	SELECT @SchSubInt01   = 0,      @SchSubInt02   = 0,      @SchSubInt03   = 0,      @SchSubInt04   = 1,      @SchSubInt05   = 0,      @SchSubInt06   = 0,      @SchSubInt07   = 0,      @SchSubInt08   = 0
	SELECT @SchRelInt01   = 0,      @SchRelInt02   = 0,      @SchRelInt03   = 0,      @SchRelInt04   = 0,      @SchRelInt05   = 0,      @SchRelInt06   = 0,      @SchRelInt07   = 0,      @SchRelInt08   = 0
	SELECT @SchFreqRec01  = 1,      @SchFreqRec02  = 1,      @SchFreqRec03  = 1,      @SchFreqRec04  = 1,      @SchFreqRec05  = 1,      @SchFreqRec06  = 1,      @SchFreqRec07  = 1,      @SchFreqRec08  = 1
	SELECT @SchStart01    = 220000, @SchStart02    = 210000, @SchStart03    = 000000, @SchStart04    = 00000,  @SchStart05    = 180000, @SchStart06    = 10000,  @SchStart07    = 000000, @SchStart08    = 50000
	SELECT @SchEnd01      = 235959, @SchEnd02      = 235959, @SchEnd03      = 235959, @SchEnd04      = 235959, @SchEnd05      = 235959, @SchEnd06      = 235959, @SchEnd07      = 235959, @SchEnd08      = 235959

	-- Update Schedules if they already esist
	IF EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE [name] = @SchName01) EXEC msdb.dbo.sp_update_schedule @name = @SchName01, @enabled = 1, @freq_type = @SchFreqType01, @freq_interval = @SchFreqInt01, @freq_subday_type = @SchSubType01, @freq_subday_interval = @SchSubInt01, @freq_relative_interval = @SchRelInt01, @freq_recurrence_factor = @SchFreqRec01, @active_start_time = @SchStart01, @active_end_time = @SchEnd01, @owner_login_name = @SchOwner;
	IF EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE [name] = @SchName02) EXEC msdb.dbo.sp_update_schedule @name = @SchName02, @enabled = 1, @freq_type = @SchFreqType02, @freq_interval = @SchFreqInt02, @freq_subday_type = @SchSubType02, @freq_subday_interval = @SchSubInt02, @freq_relative_interval = @SchRelInt02, @freq_recurrence_factor = @SchFreqRec02, @active_start_time = @SchStart02, @active_end_time = @SchEnd02, @owner_login_name = @SchOwner;
--	IF EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE [name] = @SchName03) EXEC msdb.dbo.sp_update_schedule @name = @SchName03, @enabled = 1, @freq_type = @SchFreqType03, @freq_interval = @SchFreqInt03, @freq_subday_type = @SchSubType03, @freq_subday_interval = @SchSubInt03, @freq_relative_interval = @SchRelInt03, @freq_recurrence_factor = @SchFreqRec03, @active_start_time = @SchStart03, @active_end_time = @SchEnd03, @owner_login_name = @SchOwner;
--	IF EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE [name] = @SchName04) EXEC msdb.dbo.sp_update_schedule @name = @SchName04, @enabled = 1, @freq_type = @SchFreqType04, @freq_interval = @SchFreqInt04, @freq_subday_type = @SchSubType04, @freq_subday_interval = @SchSubInt04, @freq_relative_interval = @SchRelInt04, @freq_recurrence_factor = @SchFreqRec04, @active_start_time = @SchStart04, @active_end_time = @SchEnd04, @owner_login_name = @SchOwner;
	IF EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE [name] = @SchName05) EXEC msdb.dbo.sp_update_schedule @name = @SchName05, @enabled = 1, @freq_type = @SchFreqType05, @freq_interval = @SchFreqInt05, @freq_subday_type = @SchSubType05, @freq_subday_interval = @SchSubInt05, @freq_relative_interval = @SchRelInt05, @freq_recurrence_factor = @SchFreqRec05, @active_start_time = @SchStart05, @active_end_time = @SchEnd05, @owner_login_name = @SchOwner;
	IF EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE [name] = @SchName06) EXEC msdb.dbo.sp_update_schedule @name = @SchName06, @enabled = 1, @freq_type = @SchFreqType06, @freq_interval = @SchFreqInt06, @freq_subday_type = @SchSubType06, @freq_subday_interval = @SchSubInt06, @freq_relative_interval = @SchRelInt06, @freq_recurrence_factor = @SchFreqRec06, @active_start_time = @SchStart06, @active_end_time = @SchEnd06, @owner_login_name = @SchOwner;
--	IF EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE [name] = @SchName07) EXEC msdb.dbo.sp_update_schedule @name = @SchName07, @enabled = 1, @freq_type = @SchFreqType07, @freq_interval = @SchFreqInt07, @freq_subday_type = @SchSubType07, @freq_subday_interval = @SchSubInt07, @freq_relative_interval = @SchRelInt07, @freq_recurrence_factor = @SchFreqRec07, @active_start_time = @SchStart07, @active_end_time = @SchEnd07, @owner_login_name = @SchOwner;
	IF EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE [name] = @SchName08) EXEC msdb.dbo.sp_update_schedule @name = @SchName08, @enabled = 1, @freq_type = @SchFreqType08, @freq_interval = @SchFreqInt08, @freq_subday_type = @SchSubType08, @freq_subday_interval = @SchSubInt08, @freq_relative_interval = @SchRelInt08, @freq_recurrence_factor = @SchFreqRec08, @active_start_time = @SchStart08, @active_end_time = @SchEnd08, @owner_login_name = @SchOwner;

	-- Create Schedules
	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE [name] = @SchName01) EXEC msdb.dbo.sp_add_schedule @schedule_name = @SchName01, @enabled = 1, @freq_type = @SchFreqType01, @freq_interval = @SchFreqInt01, @freq_subday_type = @SchSubType01, @freq_subday_interval = @SchSubInt01, @freq_relative_interval = @SchRelInt01, @freq_recurrence_factor = @SchFreqRec01, @active_start_time = @SchStart01, @active_end_time = @SchEnd01, @owner_login_name = @SchOwner;
	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE [name] = @SchName02) EXEC msdb.dbo.sp_add_schedule @schedule_name = @SchName02, @enabled = 1, @freq_type = @SchFreqType02, @freq_interval = @SchFreqInt02, @freq_subday_type = @SchSubType02, @freq_subday_interval = @SchSubInt02, @freq_relative_interval = @SchRelInt02, @freq_recurrence_factor = @SchFreqRec02, @active_start_time = @SchStart02, @active_end_time = @SchEnd02, @owner_login_name = @SchOwner;
--	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE [name] = @SchName03) EXEC msdb.dbo.sp_add_schedule @schedule_name = @SchName03, @enabled = 1, @freq_type = @SchFreqType03, @freq_interval = @SchFreqInt03, @freq_subday_type = @SchSubType03, @freq_subday_interval = @SchSubInt03, @freq_relative_interval = @SchRelInt03, @freq_recurrence_factor = @SchFreqRec03, @active_start_time = @SchStart03, @active_end_time = @SchEnd03, @owner_login_name = @SchOwner;
--	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE [name] = @SchName04) EXEC msdb.dbo.sp_add_schedule @schedule_name = @SchName04, @enabled = 1, @freq_type = @SchFreqType04, @freq_interval = @SchFreqInt04, @freq_subday_type = @SchSubType04, @freq_subday_interval = @SchSubInt04, @freq_relative_interval = @SchRelInt04, @freq_recurrence_factor = @SchFreqRec04, @active_start_time = @SchStart04, @active_end_time = @SchEnd04, @owner_login_name = @SchOwner;
	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE [name] = @SchName05) EXEC msdb.dbo.sp_add_schedule @schedule_name = @SchName05, @enabled = 1, @freq_type = @SchFreqType05, @freq_interval = @SchFreqInt05, @freq_subday_type = @SchSubType05, @freq_subday_interval = @SchSubInt05, @freq_relative_interval = @SchRelInt05, @freq_recurrence_factor = @SchFreqRec05, @active_start_time = @SchStart05, @active_end_time = @SchEnd05, @owner_login_name = @SchOwner;
	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE [name] = @SchName06) EXEC msdb.dbo.sp_add_schedule @schedule_name = @SchName06, @enabled = 1, @freq_type = @SchFreqType06, @freq_interval = @SchFreqInt06, @freq_subday_type = @SchSubType06, @freq_subday_interval = @SchSubInt06, @freq_relative_interval = @SchRelInt06, @freq_recurrence_factor = @SchFreqRec06, @active_start_time = @SchStart06, @active_end_time = @SchEnd06, @owner_login_name = @SchOwner;
--	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE [name] = @SchName07) EXEC msdb.dbo.sp_add_schedule @schedule_name = @SchName07, @enabled = 1, @freq_type = @SchFreqType07, @freq_interval = @SchFreqInt07, @freq_subday_type = @SchSubType07, @freq_subday_interval = @SchSubInt07, @freq_relative_interval = @SchRelInt07, @freq_recurrence_factor = @SchFreqRec07, @active_start_time = @SchStart07, @active_end_time = @SchEnd07, @owner_login_name = @SchOwner;
	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE [name] = @SchName08) EXEC msdb.dbo.sp_add_schedule @schedule_name = @SchName08, @enabled = 1, @freq_type = @SchFreqType08, @freq_interval = @SchFreqInt08, @freq_subday_type = @SchSubType08, @freq_subday_interval = @SchSubInt08, @freq_relative_interval = @SchRelInt08, @freq_recurrence_factor = @SchFreqRec08, @active_start_time = @SchStart08, @active_end_time = @SchEnd08, @owner_login_name = @SchOwner;

	-- Assign Schedules to Jobs
	IF EXISTS     (SELECT * FROM msdb.dbo.sysjobs      WHERE [name] = @JobName01) EXEC msdb.dbo.sp_attach_schedule @job_name = @JobName01, @schedule_name = @SchName01;
	IF EXISTS     (SELECT * FROM msdb.dbo.sysjobs      WHERE [name] = @JobName02) EXEC msdb.dbo.sp_attach_schedule @job_name = @JobName02, @schedule_name = @SchName02;
--	IF EXISTS     (SELECT * FROM msdb.dbo.sysjobs      WHERE [name] = @JobName03) EXEC msdb.dbo.sp_attach_schedule @job_name = @JobName03, @schedule_name = @SchName03;
--	IF EXISTS     (SELECT * FROM msdb.dbo.sysjobs      WHERE [name] = @JobName04) EXEC msdb.dbo.sp_attach_schedule @job_name = @JobName04, @schedule_name = @SchName04;
	IF EXISTS     (SELECT * FROM msdb.dbo.sysjobs      WHERE [name] = @JobName05) EXEC msdb.dbo.sp_attach_schedule @job_name = @JobName05, @schedule_name = @SchName05;
	IF EXISTS     (SELECT * FROM msdb.dbo.sysjobs      WHERE [name] = @JobName06) EXEC msdb.dbo.sp_attach_schedule @job_name = @JobName06, @schedule_name = @SchName06;
	IF EXISTS     (SELECT * FROM msdb.dbo.sysjobs      WHERE [name] = @JobName07) EXEC msdb.dbo.sp_attach_schedule @job_name = @JobName07, @schedule_name = @SchName06;
	IF EXISTS     (SELECT * FROM msdb.dbo.sysjobs      WHERE [name] = @JobName08) EXEC msdb.dbo.sp_attach_schedule @job_name = @JobName08, @schedule_name = @SchName08;
	IF EXISTS     (SELECT * FROM msdb.dbo.sysjobs      WHERE [name] = @JobName09) EXEC msdb.dbo.sp_attach_schedule @job_name = @JobName09, @schedule_name = @SchName08;
	IF EXISTS     (SELECT * FROM msdb.dbo.sysjobs      WHERE [name] = @JobName10) EXEC msdb.dbo.sp_attach_schedule @job_name = @JobName10, @schedule_name = @SchName08;
	IF EXISTS     (SELECT * FROM msdb.dbo.sysjobs      WHERE [name] = @JobName11) EXEC msdb.dbo.sp_attach_schedule @job_name = @JobName11, @schedule_name = @SchName08;

END

--	Correct job parameters for specified plan
	-- Make Indexes Smarter --
	EXEC dbo.sp_update_jobstep
		@job_name = N'IndexOptimize - USER_DATABASES',	
		@step_id = 1,
		@command=N'sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d master -Q "EXECUTE [dbo].[IndexOptimize] @Databases = ''USER_DATABASES'', @FragmentationMedium = ''INDEX_REORGANIZE,INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'', @FragmentationHigh = ''INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'', @FragmentationLevel1 = 30, @FragmentationLevel2 = 50, @UpdateStatistics = ''ALL'', @OnlyModifiedStatistics = ''Y'', @FillFactor = 90, @LogToTable = ''Y''" -b'

	-- Keep Fulls for a week --
	EXEC dbo.sp_update_jobstep
		@job_name = N'DatabaseBackup - SYSTEM_DATABASES - FULL',
		@step_id = 1,
		@command=N'sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d master -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''SYSTEM_DATABASES'', @Directory = N''V:\Backup'', @BackupType = ''FULL'', @Verify = ''Y'', @CleanupTime = 168, @CheckSum = ''Y'', @LogToTable = ''Y''" -b'
		
	EXEC dbo.sp_update_jobstep
		@job_name = N'DatabaseBackup - USER_DATABASES - FULL',
		@step_id = 1,
		@command=N'sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d master -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''USER_DATABASES'', @Directory = N''V:\Backup'', @BackupType = ''FULL'', @Verify = ''Y'', @CleanupTime = 168, @CheckSum = ''Y'', @LogToTable = ''Y''" -b'

	-- Keeps job history for 120 days
	EXEC dbo.sp_update_jobstep
		@job_name = N'CommandLog Cleanup',
		@step_id = 1,
		@command=N'sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d master -Q "DELETE FROM [dbo].[CommandLog] WHERE StartTime < DATEADD(dd,-120,GETDATE())" -b'
