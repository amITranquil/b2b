BEGIN TRANSACTION;
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

