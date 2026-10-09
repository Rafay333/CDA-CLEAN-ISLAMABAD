-- Day / Night shift for attendance marked from the Clean Islamabad app.
-- A Night shift that checks out after midnight stays on the row of the day it started.
-- The API also applies this change on its own the first time it talks to SmartSWM.
-- Safe to run more than once.

USE SmartSWM;
GO

IF COL_LENGTH('dbo.Attendances', 'Shift') IS NULL
    ALTER TABLE dbo.Attendances ADD Shift NVARCHAR(10) NULL;
GO
