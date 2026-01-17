CREATE TABLE IF NOT EXISTS "__EFMigrationsHistory" (
    "MigrationId" TEXT NOT NULL CONSTRAINT "PK___EFMigrationsHistory" PRIMARY KEY,
    "ProductVersion" TEXT NOT NULL
);

BEGIN TRANSACTION;
CREATE TABLE "AppSettings" (
    "Id" INTEGER NOT NULL CONSTRAINT "PK_AppSettings" PRIMARY KEY AUTOINCREMENT,
    "Key" TEXT NOT NULL,
    "Value" TEXT NOT NULL,
    "Description" TEXT NULL,
    "LastUpdated" TEXT NOT NULL,
    "UpdatedBy" TEXT NULL
);

CREATE TABLE "Products" (
    "Id" INTEGER NOT NULL CONSTRAINT "PK_Products" PRIMARY KEY AUTOINCREMENT,
    "ProductCode" TEXT NOT NULL,
    "Name" TEXT NOT NULL,
    "ListPrice" decimal(18,2) NOT NULL,
    "BuyPriceExcludingVat" decimal(18,2) NOT NULL,
    "BuyPriceIncludingVat" decimal(18,2) NOT NULL,
    "MyPrice" decimal(18,2) NOT NULL,
    "Discount1" decimal(5,2) NOT NULL,
    "Discount2" decimal(5,2) NOT NULL,
    "Discount3" decimal(5,2) NOT NULL,
    "VatRate" decimal(5,2) NOT NULL,
    "ImageUrl" TEXT NULL,
    "LocalImagePath" TEXT NULL,
    "MarginPercentage" decimal(5,2) NOT NULL,
    "LastUpdated" TEXT NOT NULL,
    "IsDeleted" INTEGER NOT NULL,
    "DeletedAt" TEXT NULL
);

CREATE TABLE "Quotes" (
    "Id" INTEGER NOT NULL CONSTRAINT "PK_Quotes" PRIMARY KEY AUTOINCREMENT,
    "CustomerName" TEXT NOT NULL,
    "Representative" TEXT NOT NULL,
    "PaymentTerm" TEXT NOT NULL,
    "Phone" TEXT NOT NULL,
    "Note" TEXT NOT NULL,
    "ExtraNote" TEXT NULL,
    "CreatedAt" TEXT NOT NULL,
    "ModifiedAt" TEXT NULL,
    "TotalAmount" decimal(18,2) NOT NULL,
    "VatAmount" decimal(18,2) NOT NULL,
    "IsDraft" INTEGER NOT NULL
);

CREATE TABLE "QuoteItems" (
    "Id" INTEGER NOT NULL CONSTRAINT "PK_QuoteItems" PRIMARY KEY AUTOINCREMENT,
    "QuoteId" INTEGER NOT NULL,
    "Description" TEXT NOT NULL,
    "Quantity" decimal(18,2) NOT NULL,
    "Unit" TEXT NOT NULL,
    "Price" decimal(18,2) NOT NULL,
    "VatRate" REAL NOT NULL,
    CONSTRAINT "FK_QuoteItems_Quotes_QuoteId" FOREIGN KEY ("QuoteId") REFERENCES "Quotes" ("Id") ON DELETE CASCADE
);

INSERT INTO "AppSettings" ("Id", "Description", "Key", "LastUpdated", "UpdatedBy", "Value")
VALUES (1, 'Katalog detay görüntüleme PIN kodu', 'CatalogPin', '2024-11-10 12:00:00', NULL, '1234');
SELECT changes();

INSERT INTO "AppSettings" ("Id", "Description", "Key", "LastUpdated", "UpdatedBy", "Value")
VALUES (2, 'Oturum süresi (saat)', 'SessionDurationHours', '2024-11-10 12:00:00', NULL, '1');
SELECT changes();


CREATE UNIQUE INDEX "IX_AppSettings_Key" ON "AppSettings" ("Key");

CREATE UNIQUE INDEX "IX_Products_ProductCode" ON "Products" ("ProductCode");

CREATE INDEX "IX_QuoteItems_QuoteId" ON "QuoteItems" ("QuoteId");

INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
VALUES ('20251110071926_InitialMigration', '9.0.7');

INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
VALUES ('20251114073614_AddVatRateToQuoteItems', '9.0.7');

CREATE TABLE "ManualProducts" (
    "Id" INTEGER NOT NULL CONSTRAINT "PK_ManualProducts" PRIMARY KEY AUTOINCREMENT,
    "ProductCode" TEXT NOT NULL,
    "Name" TEXT NOT NULL,
    "BuyPrice" decimal(18,2) NOT NULL,
    "ProfitMargin" decimal(5,2) NOT NULL,
    "VatRate" decimal(5,2) NOT NULL,
    "CreatedAt" TEXT NOT NULL,
    "LastUpdated" TEXT NOT NULL,
    "IsDeleted" INTEGER NOT NULL,
    "DeletedAt" TEXT NULL
);

CREATE UNIQUE INDEX "IX_ManualProducts_ProductCode" ON "ManualProducts" ("ProductCode");

INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
VALUES ('20251121084753_AddManualProducts', '9.0.7');

ALTER TABLE "QuoteItems" ADD "MarginPercentage" REAL NOT NULL DEFAULT 0.0;

INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
VALUES ('20251121101107_AddMarginPercentageToQuoteItem', '9.0.7');

CREATE TABLE "Sales" (
    "Id" INTEGER NOT NULL CONSTRAINT "PK_Sales" PRIMARY KEY AUTOINCREMENT,
    "CreatedAt" TEXT NOT NULL,
    "Subtotal" decimal(18,2) NOT NULL,
    "CardCommission" decimal(18,2) NOT NULL,
    "Total" decimal(18,2) NOT NULL,
    "PaymentMethod" TEXT NOT NULL,
    "Status" TEXT NOT NULL
);

CREATE TABLE "SaleItems" (
    "Id" INTEGER NOT NULL CONSTRAINT "PK_SaleItems" PRIMARY KEY AUTOINCREMENT,
    "SaleId" INTEGER NOT NULL,
    "ProductCode" TEXT NOT NULL,
    "ProductName" TEXT NOT NULL,
    "Quantity" decimal(18,2) NOT NULL,
    "Unit" TEXT NOT NULL,
    "Price" decimal(18,2) NOT NULL,
    "VatRate" decimal(18,2) NOT NULL,
    CONSTRAINT "FK_SaleItems_Sales_SaleId" FOREIGN KEY ("SaleId") REFERENCES "Sales" ("Id") ON DELETE CASCADE
);

CREATE INDEX "IX_SaleItems_SaleId" ON "SaleItems" ("SaleId");

INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
VALUES ('20260116090619_AddSalesAndSaleItems', '9.0.7');

COMMIT;

