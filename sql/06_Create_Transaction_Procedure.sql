USE BankCore;
GO

CREATE OR ALTER PROCEDURE dbo.usp_TransferMoney
    @FromAccountID BIGINT,
    @ToAccountID BIGINT,
    @Amount DECIMAL(18,2),
    @Description VARCHAR(255)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @TransactionID BIGINT;
    DECLARE @ReferenceNumber VARCHAR(30);
    DECLARE @CurrentBalance DECIMAL(18,2);
    DECLARE @FromStatus VARCHAR(20);
    DECLARE @ToStatus VARCHAR(20);

    BEGIN TRY
        IF @FromAccountID=@ToAccountID
            THROW 50001,'Source and destination accounts must be different.',1;

        IF @Amount IS NULL OR @Amount<=0
            THROW 50002,'Transfer amount must be greater than zero.',1;

        BEGIN TRANSACTION;

        /*
           Concurrency control:
           Lock both account rows in deterministic AccountID order.
           UPDLOCK prevents two concurrent transfers from both passing
           the same balance check; HOLDLOCK keeps the locks to COMMIT.
        */
        IF @FromAccountID < @ToAccountID
        BEGIN
            SELECT @FromStatus=AccountStatus
            FROM dbo.Accounts WITH (UPDLOCK,HOLDLOCK)
            WHERE AccountID=@FromAccountID;

            SELECT @ToStatus=AccountStatus
            FROM dbo.Accounts WITH (UPDLOCK,HOLDLOCK)
            WHERE AccountID=@ToAccountID;
        END
        ELSE
        BEGIN
            SELECT @ToStatus=AccountStatus
            FROM dbo.Accounts WITH (UPDLOCK,HOLDLOCK)
            WHERE AccountID=@ToAccountID;

            SELECT @FromStatus=AccountStatus
            FROM dbo.Accounts WITH (UPDLOCK,HOLDLOCK)
            WHERE AccountID=@FromAccountID;
        END;

        IF @FromStatus IS NULL OR @FromStatus<>'ACTIVE'
            THROW 50003,'Source account does not exist or is not ACTIVE.',1;

        IF @ToStatus IS NULL OR @ToStatus<>'ACTIVE'
            THROW 50004,'Destination account does not exist or is not ACTIVE.',1;

        /* The account-row locks serialize transfers from the same source. */
        SELECT @CurrentBalance=COALESCE(SUM(CASE
                    WHEN E.EntryType='CREDIT' THEN E.Amount
                    WHEN E.EntryType='DEBIT' THEN -E.Amount
                    ELSE 0 END),0)
        FROM dbo.TransactionEntries E
        JOIN dbo.Transactions T ON T.TransactionID=E.TransactionID
        WHERE E.AccountID=@FromAccountID
          AND T.TransactionStatus='SUCCESS';

        IF COALESCE(@CurrentBalance,0)<@Amount
            THROW 50005,'Insufficient account balance.',1;

        SET @ReferenceNumber =
            CONCAT('TRF-',LEFT(REPLACE(CONVERT(VARCHAR(36),NEWID()),'-',''),24));

        /* Post in PENDING state, write both entries, then mark SUCCESS. */
        INSERT INTO dbo.Transactions
        (ReferenceNumber,TransactionType,TransactionStatus,Amount,CurrencyCode,Description)
        VALUES
        (@ReferenceNumber,'TRANSFER','PENDING',@Amount,'INR',@Description);

        SET @TransactionID=SCOPE_IDENTITY();

        INSERT INTO dbo.TransactionEntries(TransactionID,AccountID,EntryType,Amount)
        VALUES
        (@TransactionID,@FromAccountID,'DEBIT',@Amount),
        (@TransactionID,@ToAccountID,'CREDIT',@Amount);

        UPDATE dbo.Transactions
        SET TransactionStatus='SUCCESS'
        WHERE TransactionID=@TransactionID;

        COMMIT;

        SELECT @TransactionID AS TransactionID,
               @ReferenceNumber AS ReferenceNumber,
               @Amount AS Amount,
               'SUCCESS' AS TransactionStatus;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH
END;
GO
