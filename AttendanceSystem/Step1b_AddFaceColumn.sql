USE faceAttendanceDb;
GO
IF COL_LENGTH('Employees','FaceEncoding') IS NULL ALTER TABLE Employees ADD FaceEncoding VARBINARY(MAX) NULL;
GO
