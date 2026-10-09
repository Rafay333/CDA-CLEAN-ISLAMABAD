-- Shift chosen when a worker's face is registered: Day, Evening, or Night.
-- Attendance uses this value, so the attendance screen does not ask again.
-- The API also applies this change the first time it talks to SmartSWM.
-- Safe to run more than once.

USE SmartSWM;
GO

IF COL_LENGTH('dbo.Employees', 'Shift') IS NULL
    ALTER TABLE dbo.Employees ADD Shift NVARCHAR(20) NULL;
GO
