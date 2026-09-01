/*
阶段一：数据准备
概述：创建 Olist_Ecommerce_Learning 数据库及核心业务表，完成原始数据导入与清洗，并通过主键、外键、索引、行数、重复值和引用完整性检查建立可分析的数据基础。
*/

IF DB_ID(N'Olist_Ecommerce_Learning') IS NULL
BEGIN

    CREATE DATABASE Olist_Ecommerce_Learning;
END;
GO

USE Olist_Ecommerce_Learning;
GO

SELECT

    QUOTENAME(s.name) + N'.' + QUOTENAME(t.name) AS N'表名',

    SUM(p.rows) AS N'数据行数'

FROM sys.tables AS t

JOIN sys.schemas AS s
    ON t.schema_id = s.schema_id

JOIN sys.partitions AS p
    ON t.object_id = p.object_id

WHERE

    t.name LIKE N'stg[_]%'

    AND p.index_id IN (0, 1)

GROUP BY
    s.name,
    t.name

ORDER BY
    t.name;

DROP VIEW IF EXISTS dbo.v_geolocation_zip_prefix;
DROP TABLE IF EXISTS dbo.order_reviews;
DROP TABLE IF EXISTS dbo.order_payments;
DROP TABLE IF EXISTS dbo.order_items;
DROP TABLE IF EXISTS dbo.orders;
DROP TABLE IF EXISTS dbo.products;
DROP TABLE IF EXISTS dbo.sellers;
DROP TABLE IF EXISTS dbo.product_category_name_translation;
DROP TABLE IF EXISTS dbo.customers;
DROP TABLE IF EXISTS dbo.geolocation;
GO

CREATE TABLE dbo.customers
(
    customer_id NVARCHAR(50) NOT NULL,
    customer_unique_id NVARCHAR(50) NULL,
    customer_zip_code_prefix NVARCHAR(10) NULL,
    customer_city NVARCHAR(100) NULL,
    customer_state NVARCHAR(2) NULL,

    CONSTRAINT PK_customers PRIMARY KEY (customer_id)
);

CREATE TABLE dbo.product_category_name_translation
(

    product_category_name NVARCHAR(100) NOT NULL,
    product_category_name_english NVARCHAR(100) NULL,

    CONSTRAINT PK_product_category_name_translation
        PRIMARY KEY (product_category_name)
);

CREATE TABLE dbo.sellers
(
    seller_id NVARCHAR(50) NOT NULL,
    seller_zip_code_prefix NVARCHAR(10) NULL,
    seller_city NVARCHAR(100) NULL,
    seller_state NVARCHAR(2) NULL,

    CONSTRAINT PK_sellers PRIMARY KEY (seller_id)
);

CREATE TABLE dbo.products
(
    product_id NVARCHAR(50) NOT NULL,
    product_category_name NVARCHAR(100) NULL,
    product_name_lenght INT NULL,
    product_description_lenght INT NULL,
    product_photos_qty INT NULL,
    product_weight_g INT NULL,
    product_length_cm INT NULL,
    product_height_cm INT NULL,
    product_width_cm INT NULL,

    CONSTRAINT PK_products PRIMARY KEY (product_id)
);

CREATE TABLE dbo.orders
(
    order_id NVARCHAR(50) NOT NULL,
    customer_id NVARCHAR(50) NOT NULL,
    order_status NVARCHAR(30) NULL,
    order_purchase_timestamp DATETIME2(0) NULL,
    order_approved_at DATETIME2(0) NULL,
    order_delivered_carrier_date DATETIME2(0) NULL,
    order_delivered_customer_date DATETIME2(0) NULL,
    order_estimated_delivery_date DATETIME2(0) NULL,

    CONSTRAINT PK_orders PRIMARY KEY (order_id)
);

CREATE TABLE dbo.order_items
(
    order_id NVARCHAR(50) NOT NULL,
    order_item_id INT NOT NULL,
    product_id NVARCHAR(50) NULL,
    seller_id NVARCHAR(50) NULL,
    shipping_limit_date DATETIME2(0) NULL,
    price DECIMAL(18,2) NULL,
    freight_value DECIMAL(18,2) NULL,

    CONSTRAINT PK_order_items
        PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE dbo.order_payments
(
    order_id NVARCHAR(50) NOT NULL,
    payment_sequential INT NOT NULL,
    payment_type NVARCHAR(30) NULL,
    payment_installments INT NULL,
    payment_value DECIMAL(18,2) NULL,

    CONSTRAINT PK_order_payments
        PRIMARY KEY (order_id, payment_sequential)
);

CREATE TABLE dbo.order_reviews
(
    review_id NVARCHAR(50) NOT NULL,
    order_id NVARCHAR(50) NOT NULL,
    review_score INT NULL,
    review_comment_title NVARCHAR(255) NULL,
    review_comment_message NVARCHAR(MAX) NULL,
    review_creation_date DATETIME2(0) NULL,
    review_answer_timestamp DATETIME2(0) NULL,

    CONSTRAINT PK_order_reviews
        PRIMARY KEY (review_id, order_id)
);

CREATE TABLE dbo.geolocation
(
    geolocation_id BIGINT IDENTITY(1,1) NOT NULL,
    geolocation_zip_code_prefix NVARCHAR(10) NULL,
    geolocation_lat DECIMAL(18,15) NULL,
    geolocation_lng DECIMAL(18,15) NULL,
    geolocation_city NVARCHAR(100) NULL,
    geolocation_state NVARCHAR(2) NULL,

    CONSTRAINT PK_geolocation
        PRIMARY KEY (geolocation_id)
);
GO

INSERT INTO dbo.customers
(
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
)
SELECT

    NULLIF(LTRIM(RTRIM(customer_id)), N'') AS customer_id,

    NULLIF(LTRIM(RTRIM(customer_unique_id)), N'') AS customer_unique_id,

    CASE
        WHEN NULLIF(LTRIM(RTRIM(customer_zip_code_prefix)), N'') IS NULL THEN NULL
        ELSE RIGHT(N'00000' + LTRIM(RTRIM(customer_zip_code_prefix)), 5)
    END AS customer_zip_code_prefix,

    NULLIF(LTRIM(RTRIM(customer_city)), N'') AS customer_city,
    NULLIF(LTRIM(RTRIM(customer_state)), N'') AS customer_state
FROM dbo.stg_olist_customers_dataset
WHERE NULLIF(LTRIM(RTRIM(customer_id)), N'') IS NOT NULL;

INSERT INTO dbo.product_category_name_translation
(
    product_category_name,
    product_category_name_english
)
SELECT
    NULLIF(LTRIM(RTRIM(product_category_name)), N'') AS product_category_name,
    NULLIF(LTRIM(RTRIM(product_category_name_english)), N'') AS product_category_name_english
FROM dbo.stg_product_category_name_translation
WHERE NULLIF(LTRIM(RTRIM(product_category_name)), N'') IS NOT NULL;

INSERT INTO dbo.sellers
(
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
)
SELECT
    NULLIF(LTRIM(RTRIM(seller_id)), N'') AS seller_id,
    CASE
        WHEN NULLIF(LTRIM(RTRIM(seller_zip_code_prefix)), N'') IS NULL THEN NULL
        ELSE RIGHT(N'00000' + LTRIM(RTRIM(seller_zip_code_prefix)), 5)
    END AS seller_zip_code_prefix,
    NULLIF(LTRIM(RTRIM(seller_city)), N'') AS seller_city,
    NULLIF(LTRIM(RTRIM(seller_state)), N'') AS seller_state
FROM dbo.stg_olist_sellers_dataset
WHERE NULLIF(LTRIM(RTRIM(seller_id)), N'') IS NOT NULL;

INSERT INTO dbo.products
(
    product_id,
    product_category_name,
    product_name_lenght,
    product_description_lenght,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
)
SELECT
    NULLIF(LTRIM(RTRIM(product_id)), N'') AS product_id,
    NULLIF(LTRIM(RTRIM(product_category_name)), N'') AS product_category_name,

    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(product_name_lenght)), N'')) AS product_name_lenght,
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(product_description_lenght)), N'')) AS product_description_lenght,
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(product_photos_qty)), N'')) AS product_photos_qty,
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(product_weight_g)), N'')) AS product_weight_g,
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(product_length_cm)), N'')) AS product_length_cm,
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(product_height_cm)), N'')) AS product_height_cm,
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(product_width_cm)), N'')) AS product_width_cm
FROM dbo.stg_olist_products_dataset
WHERE NULLIF(LTRIM(RTRIM(product_id)), N'') IS NOT NULL;

INSERT INTO dbo.orders
(
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
)
SELECT
    NULLIF(LTRIM(RTRIM(order_id)), N'') AS order_id,
    NULLIF(LTRIM(RTRIM(customer_id)), N'') AS customer_id,
    NULLIF(LTRIM(RTRIM(order_status)), N'') AS order_status,

    TRY_CONVERT(DATETIME2(0), NULLIF(LTRIM(RTRIM(order_purchase_timestamp)), N''), 120) AS order_purchase_timestamp,
    TRY_CONVERT(DATETIME2(0), NULLIF(LTRIM(RTRIM(order_approved_at)), N''), 120) AS order_approved_at,
    TRY_CONVERT(DATETIME2(0), NULLIF(LTRIM(RTRIM(order_delivered_carrier_date)), N''), 120) AS order_delivered_carrier_date,
    TRY_CONVERT(DATETIME2(0), NULLIF(LTRIM(RTRIM(order_delivered_customer_date)), N''), 120) AS order_delivered_customer_date,
    TRY_CONVERT(DATETIME2(0), NULLIF(LTRIM(RTRIM(order_estimated_delivery_date)), N''), 120) AS order_estimated_delivery_date
FROM dbo.stg_olist_orders_dataset
WHERE NULLIF(LTRIM(RTRIM(order_id)), N'') IS NOT NULL;

INSERT INTO dbo.order_items
(
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value
)
SELECT
    NULLIF(LTRIM(RTRIM(order_id)), N'') AS order_id,
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(order_item_id)), N'')) AS order_item_id,
    NULLIF(LTRIM(RTRIM(product_id)), N'') AS product_id,
    NULLIF(LTRIM(RTRIM(seller_id)), N'') AS seller_id,
    TRY_CONVERT(DATETIME2(0), NULLIF(LTRIM(RTRIM(shipping_limit_date)), N''), 120) AS shipping_limit_date,
    TRY_CONVERT(DECIMAL(18,2), NULLIF(LTRIM(RTRIM(price)), N'')) AS price,
    TRY_CONVERT(DECIMAL(18,2), NULLIF(LTRIM(RTRIM(freight_value)), N'')) AS freight_value
FROM dbo.stg_olist_order_items_dataset
WHERE NULLIF(LTRIM(RTRIM(order_id)), N'') IS NOT NULL
  AND TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(order_item_id)), N'')) IS NOT NULL;

INSERT INTO dbo.order_payments
(
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
)
SELECT
    NULLIF(LTRIM(RTRIM(order_id)), N'') AS order_id,
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(payment_sequential)), N'')) AS payment_sequential,
    NULLIF(LTRIM(RTRIM(payment_type)), N'') AS payment_type,
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(payment_installments)), N'')) AS payment_installments,
    TRY_CONVERT(DECIMAL(18,2), NULLIF(LTRIM(RTRIM(payment_value)), N'')) AS payment_value
FROM dbo.stg_olist_order_payments_dataset
WHERE NULLIF(LTRIM(RTRIM(order_id)), N'') IS NOT NULL
  AND TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(payment_sequential)), N'')) IS NOT NULL;

INSERT INTO dbo.order_reviews
(
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
)
SELECT
    NULLIF(LTRIM(RTRIM(review_id)), N'') AS review_id,
    NULLIF(LTRIM(RTRIM(order_id)), N'') AS order_id,
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(review_score)), N'')) AS review_score,

    LEFT(NULLIF(LTRIM(RTRIM(review_comment_title)), N''), 255) AS review_comment_title,

    NULLIF(LTRIM(RTRIM(review_comment_message)), N'') AS review_comment_message,

    TRY_CONVERT(DATETIME2(0), NULLIF(LTRIM(RTRIM(review_creation_date)), N''), 120) AS review_creation_date,
    TRY_CONVERT(DATETIME2(0), NULLIF(LTRIM(RTRIM(review_answer_timestamp)), N''), 120) AS review_answer_timestamp
FROM dbo.stg_olist_order_reviews_dataset
WHERE NULLIF(LTRIM(RTRIM(review_id)), N'') IS NOT NULL
  AND NULLIF(LTRIM(RTRIM(order_id)), N'') IS NOT NULL;

INSERT INTO dbo.geolocation
(
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
)
SELECT
    CASE
        WHEN NULLIF(LTRIM(RTRIM(geolocation_zip_code_prefix)), N'') IS NULL THEN NULL
        ELSE RIGHT(N'00000' + LTRIM(RTRIM(geolocation_zip_code_prefix)), 5)
    END AS geolocation_zip_code_prefix,

    TRY_CONVERT(DECIMAL(18,15), NULLIF(LTRIM(RTRIM(geolocation_lat)), N'')) AS geolocation_lat,
    TRY_CONVERT(DECIMAL(18,15), NULLIF(LTRIM(RTRIM(geolocation_lng)), N'')) AS geolocation_lng,
    NULLIF(LTRIM(RTRIM(geolocation_city)), N'') AS geolocation_city,
    NULLIF(LTRIM(RTRIM(geolocation_state)), N'') AS geolocation_state
FROM dbo.stg_olist_geolocation_dataset;
GO

SELECT
   N'customers' AS table_name,
   COUNT_BIG(*) AS actual_rows,
   99441 AS expected_rows
FROM dbo.customers

UNION ALL
SELECT N'orders' AS table_name, COUNT_BIG(*) AS actual_rows, 99441 AS expected_rows
FROM dbo.orders
UNION ALL
SELECT N'products' AS table_name, COUNT_BIG(*) AS actual_rows, 32951 AS expected_rows
FROM dbo.products
UNION ALL
SELECT N'sellers' AS table_name, COUNT_BIG(*) AS actual_rows, 3095 AS expected_rows
FROM dbo.sellers
UNION ALL
SELECT N'product_category_name_translation' AS table_name, COUNT_BIG(*) AS actual_rows, 71 AS expected_rows
FROM dbo.product_category_name_translation
UNION ALL
SELECT N'order_items' AS table_name, COUNT_BIG(*) AS actual_rows, 112650 AS expected_rows
FROM dbo.order_items
UNION ALL
SELECT N'order_payments' AS table_name, COUNT_BIG(*) AS actual_rows, 103886 AS expected_rows
FROM dbo.order_payments
UNION ALL
SELECT N'order_reviews' AS table_name, COUNT_BIG(*) AS actual_rows, 99224 AS expected_rows
FROM dbo.order_reviews
UNION ALL
SELECT N'geolocation' AS table_name, COUNT_BIG(*) AS actual_rows, 1000163 AS expected_rows
FROM dbo.geolocation;

SELECT customer_id, COUNT(*) AS duplicate_count
FROM dbo.customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

SELECT order_id, COUNT(*) AS duplicate_count
FROM dbo.orders
GROUP BY order_id
HAVING COUNT(*) > 1;

SELECT product_id, COUNT(*) AS duplicate_count
FROM dbo.products
GROUP BY product_id
HAVING COUNT(*) > 1;

SELECT seller_id, COUNT(*) AS duplicate_count
FROM dbo.sellers
GROUP BY seller_id
HAVING COUNT(*) > 1;

SELECT review_id, COUNT(*) AS rows_with_same_review_id
FROM dbo.order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY rows_with_same_review_id DESC;

SELECT COUNT(*) AS orders_without_customer
FROM dbo.orders AS o
LEFT JOIN dbo.customers AS c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

SELECT COUNT(*) AS order_items_without_order
FROM dbo.order_items AS oi
LEFT JOIN dbo.orders AS o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

SELECT COUNT(*) AS order_items_without_product
FROM dbo.order_items AS oi
LEFT JOIN dbo.products AS p
    ON oi.product_id = p.product_id
WHERE oi.product_id IS NOT NULL
  AND p.product_id IS NULL;

SELECT COUNT(*) AS order_items_without_seller
FROM dbo.order_items AS oi
LEFT JOIN dbo.sellers AS s
    ON oi.seller_id = s.seller_id
WHERE oi.seller_id IS NOT NULL
  AND s.seller_id IS NULL;

SELECT COUNT(*) AS payments_without_order
FROM dbo.order_payments AS op
LEFT JOIN dbo.orders AS o
    ON op.order_id = o.order_id
WHERE o.order_id IS NULL;

SELECT COUNT(*) AS reviews_without_order
FROM dbo.order_reviews AS r
LEFT JOIN dbo.orders AS o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;

SELECT COUNT(*) AS products_without_category_translation
FROM dbo.products AS p
LEFT JOIN dbo.product_category_name_translation AS t
    ON p.product_category_name = t.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND t.product_category_name IS NULL;

ALTER TABLE dbo.orders
ADD CONSTRAINT FK_orders_customers
FOREIGN KEY (customer_id)
REFERENCES dbo.customers (customer_id);

ALTER TABLE dbo.order_items
ADD CONSTRAINT FK_order_items_orders
FOREIGN KEY (order_id)
REFERENCES dbo.orders (order_id);

ALTER TABLE dbo.order_items
ADD CONSTRAINT FK_order_items_products
FOREIGN KEY (product_id)
REFERENCES dbo.products (product_id);

ALTER TABLE dbo.order_items
ADD CONSTRAINT FK_order_items_sellers
FOREIGN KEY (seller_id)
REFERENCES dbo.sellers (seller_id);

ALTER TABLE dbo.order_payments
ADD CONSTRAINT FK_order_payments_orders
FOREIGN KEY (order_id)
REFERENCES dbo.orders (order_id);

ALTER TABLE dbo.order_reviews
ADD CONSTRAINT FK_order_reviews_orders
FOREIGN KEY (order_id)
REFERENCES dbo.orders (order_id);
GO

CREATE INDEX IX_orders_customer_id
ON dbo.orders (customer_id);

CREATE INDEX IX_orders_purchase_time
ON dbo.orders (order_purchase_timestamp);

CREATE INDEX IX_order_items_product_id
ON dbo.order_items (product_id);

CREATE INDEX IX_order_items_seller_id
ON dbo.order_items (seller_id);

CREATE INDEX IX_order_payments_order_id
ON dbo.order_payments (order_id);

CREATE INDEX IX_order_reviews_order_id
ON dbo.order_reviews (order_id);

CREATE INDEX IX_customers_zip_state
ON dbo.customers (customer_zip_code_prefix, customer_state);

CREATE INDEX IX_sellers_zip_state
ON dbo.sellers (seller_zip_code_prefix, seller_state);

CREATE INDEX IX_geolocation_zip
ON dbo.geolocation (geolocation_zip_code_prefix);
GO

CREATE OR ALTER VIEW dbo.v_geolocation_zip_prefix
AS
SELECT
    geolocation_zip_code_prefix,
    AVG(CAST(geolocation_lat AS FLOAT)) AS avg_geolocation_lat,
    AVG(CAST(geolocation_lng AS FLOAT)) AS avg_geolocation_lng,
    MAX(geolocation_city) AS example_city,
    MAX(geolocation_state) AS example_state,
    COUNT_BIG(*) AS source_row_count
FROM dbo.geolocation
WHERE geolocation_zip_code_prefix IS NOT NULL
GROUP BY geolocation_zip_code_prefix;
GO

SELECT TOP (10) *
FROM dbo.orders;

SELECT TOP (10) *
FROM dbo.order_items;

SELECT TOP (10) *
FROM dbo.order_reviews;

SELECT TOP (10) *
FROM dbo.v_geolocation_zip_prefix;
