USE BankCore;
GO

INSERT INTO dbo.Branches (BranchCode,BranchName,City,State,IFSCCode)
VALUES
('BC001','BankCore Warangal','Warangal','Telangana','BKCX0000001'),
('BC002','BankCore Hyderabad','Hyderabad','Telangana','BKCX0000002'),
('BC003','BankCore Vijayawada','Vijayawada','Andhra Pradesh','BKCX0000003'),
('BC004','BankCore Bengaluru','Bengaluru','Karnataka','BKCX0000004'),
('BC005','BankCore Mumbai','Mumbai','Maharashtra','BKCX0000005'),
('BC006','BankCore Delhi','New Delhi','Delhi','BKCX0000006'),
('BC007','BankCore Jaipur','Jaipur','Rajasthan','BKCX0000007'),
('BC008','BankCore Lucknow','Lucknow','Uttar Pradesh','BKCX0000008'),
('BC009','BankCore Bhopal','Bhopal','Madhya Pradesh','BKCX0000009'),
('BC010','BankCore Pune','Pune','Maharashtra','BKCX0000010');
GO

;WITH Numbers AS
(
    SELECT TOP (5000)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS N
    FROM sys.all_objects A
    CROSS JOIN sys.all_objects B
)
INSERT INTO dbo.Customers
(
    FirstName,LastName,DateOfBirth,Email,Phone,KYCStatus,CreatedAt
)
SELECT
    CASE N % 10
        WHEN 0 THEN 'Aarav' WHEN 1 THEN 'Vivaan' WHEN 2 THEN 'Aditya'
        WHEN 3 THEN 'Arjun' WHEN 4 THEN 'Vihaan' WHEN 5 THEN 'Sai'
        WHEN 6 THEN 'Ishaan' WHEN 7 THEN 'Kabir' WHEN 8 THEN 'Krishna'
        ELSE 'Reyansh' END,
    CASE N % 10
        WHEN 0 THEN 'Sharma' WHEN 1 THEN 'Verma' WHEN 2 THEN 'Gupta'
        WHEN 3 THEN 'Patel' WHEN 4 THEN 'Reddy' WHEN 5 THEN 'Singh'
        WHEN 6 THEN 'Kumar' WHEN 7 THEN 'Mehta' WHEN 8 THEN 'Das'
        ELSE 'Yadav' END,
    DATEADD(DAY,-(7000 + (N*17 % 12000)),CAST(GETDATE() AS DATE)),
    CONCAT('customer',N,'@bankcore.test'),
    CONCAT('9',RIGHT('000000000'+CAST(N AS VARCHAR(9)),9)),
    CASE WHEN N % 20 = 0 THEN 'PENDING'
         WHEN N % 100 = 0 THEN 'REJECTED'
         ELSE 'VERIFIED' END,
    DATEADD(DAY,-(N % 2000),SYSDATETIME())
FROM Numbers;
GO

SELECT COUNT(*) AS Branches FROM dbo.Branches;
SELECT COUNT(*) AS Customers FROM dbo.Customers;
