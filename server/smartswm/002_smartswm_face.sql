-- Face photos and match score for the Clean Islamabad app.
-- Registration stores three photos, the same way as the attendance mobile app.
-- Safe to run more than once.

USE SmartSWM;
GO

IF COL_LENGTH('dbo.Employees', 'FaceImage') IS NULL
    ALTER TABLE dbo.Employees ADD FaceImage VARBINARY(MAX) NULL;
GO
IF COL_LENGTH('dbo.Employees', 'FaceRegisteredAt') IS NULL
    ALTER TABLE dbo.Employees ADD FaceRegisteredAt DATETIME2 NULL;
GO
IF COL_LENGTH('dbo.Attendances', 'Similarity') IS NULL
    ALTER TABLE dbo.Attendances ADD Similarity FLOAT NULL;
GO

IF OBJECT_ID('dbo.EmployeeFaces', 'U') IS NULL
CREATE TABLE dbo.EmployeeFaces (
    FaceId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_EmployeeFaces PRIMARY KEY,
    EmployeeId INT NOT NULL,
    Image VARBINARY(MAX) NOT NULL,
    Encoding VARBINARY(1024) NULL,
    Created DATETIME2 NOT NULL CONSTRAINT DF_EmployeeFaces_Created DEFAULT SYSDATETIME(),
    CONSTRAINT FK_EmployeeFaces_Employees FOREIGN KEY (EmployeeId) REFERENCES dbo.Employees (EmployeeId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_EmployeeFaces_EmployeeId' AND object_id = OBJECT_ID('dbo.EmployeeFaces'))
    CREATE INDEX IX_EmployeeFaces_EmployeeId ON dbo.EmployeeFaces (EmployeeId);
GO

IF OBJECT_ID('dbo.CheckinPhotos', 'U') IS NULL
CREATE TABLE dbo.CheckinPhotos (
    Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CheckinPhotos PRIMARY KEY,
    EmployeeId INT NOT NULL,
    Time DATETIME2 NOT NULL,
    Status NVARCHAR(20) NOT NULL,
    Motion FLOAT NULL,
    Blink FLOAT NULL,
    Img1 VARBINARY(MAX) NULL,
    Img2 VARBINARY(MAX) NULL,
    Img3 VARBINARY(MAX) NULL,
    Feat VARBINARY(MAX) NULL,
    CONSTRAINT FK_CheckinPhotos_Employees FOREIGN KEY (EmployeeId) REFERENCES dbo.Employees (EmployeeId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CheckinPhotos_Employee_Time' AND object_id = OBJECT_ID('dbo.CheckinPhotos'))
    CREATE INDEX IX_CheckinPhotos_Employee_Time ON dbo.CheckinPhotos (EmployeeId, Time);
GO
