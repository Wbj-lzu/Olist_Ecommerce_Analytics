/*
阶段二：基础查询
概述：使用筛选、排序、聚合、分组和多表关联完成订单、客户、商品、支付、评价、卖家及物流数据的基础探索，为后续分析确认业务口径。
*/

USE Olist_Ecommerce_Learning;
GO

SELECT

    N'customers' AS table_name,
    COUNT_BIG(*) AS row_count
FROM dbo.customers

UNION ALL
SELECT N'orders' AS table_name, COUNT_BIG(*) AS row_count
FROM dbo.orders

UNION ALL
SELECT N'order_items' AS table_name, COUNT_BIG(*) AS row_count
FROM dbo.order_items

UNION ALL
SELECT N'order_payments' AS table_name, COUNT_BIG(*) AS row_count
FROM dbo.order_payments

UNION ALL
SELECT N'order_reviews' AS table_name, COUNT_BIG(*) AS row_count
FROM dbo.order_reviews

UNION ALL
SELECT N'products' AS table_name, COUNT_BIG(*) AS row_count
FROM dbo.products

UNION ALL
SELECT N'sellers' AS table_name, COUNT_BIG(*) AS row_count
FROM dbo.sellers

UNION ALL
SELECT N'product_category_name_translation' AS table_name, COUNT_BIG(*) AS row_count
FROM dbo.product_category_name_translation

UNION ALL
SELECT N'geolocation' AS table_name, COUNT_BIG(*) AS row_count
FROM dbo.geolocation
ORDER BY table_name;

SELECT TOP (10)
    *
FROM dbo.customers
ORDER BY customer_id;

SELECT TOP (10)
    *
FROM dbo.orders
ORDER BY order_purchase_timestamp, order_id;

SELECT TOP (10)
    *
FROM dbo.order_items
ORDER BY order_id, order_item_id;

SELECT TOP (10)
    *
FROM dbo.order_payments
ORDER BY order_id, payment_sequential;

SELECT TOP (10)
    *
FROM dbo.order_reviews
ORDER BY order_id, review_id;

SELECT TOP (10)
    *
FROM dbo.products
ORDER BY product_id;

SELECT TOP (10)
    *
FROM dbo.sellers
ORDER BY seller_id;

SELECT TOP (10)
    *
FROM dbo.product_category_name_translation
ORDER BY product_category_name;

SELECT TOP (10)
    *
FROM dbo.v_geolocation_zip_prefix
ORDER BY geolocation_zip_code_prefix;

SELECT
    N'oders' AS table_name,
    COUNT_BIG(*) AS total_orders
FROM dbo.orders

UNION ALL

SELECT
    N'oders_items' AS table_name,
    COUNT_BIG(*) AS total_order_item_rows
FROM dbo.order_items;

SELECT
    COUNT(DISTINCT order_id) AS distinct_orders_in_order_items,
    COUNT_BIG(*) AS item_row_count
FROM dbo.order_items;

SELECT DISTINCT
    customer_state
FROM dbo.customers
WHERE customer_state IS NOT NULL
ORDER BY customer_state;

SELECT TOP (100)
    customer_id,
    customer_unique_id,
    customer_city,
    customer_state,
    customer_zip_code_prefix
FROM dbo.customers
WHERE LOWER(customer_city) = N'sao paulo'
ORDER BY customer_id;

DECLARE @StartDate DATETIME2(0) = '2017-01-01T00:00:00';
DECLARE @EndDateExclusive DATETIME2(0) = '2018-02-02T00:00:00';

SELECT TOP (200)
    o.order_id,
    o.order_purchase_timestamp,
    o.order_status,
    op.payment_sequential,
    op.payment_type,
    op.payment_installments,
    op.payment_value
FROM dbo.orders AS o
INNER JOIN dbo.order_payments AS op
    ON o.order_id = op.order_id
WHERE o.order_purchase_timestamp >= @StartDate
  AND o.order_purchase_timestamp < @EndDateExclusive
ORDER BY
    o.order_purchase_timestamp,
    o.order_id,
    op.payment_sequential;

SELECT TOP (5)
    o.order_id,
    o.order_purchase_timestamp,
    o.order_status,
    SUM(ISNULL(op.payment_value, 0)) AS total_payment
FROM dbo.orders AS o
INNER JOIN dbo.order_payments AS op
    ON o.order_id = op.order_id
GROUP BY
    o.order_id,
    o.order_purchase_timestamp,
    o.order_status
ORDER BY
    total_payment DESC,
    o.order_id;

SELECT TOP (200)
    o.order_id,
    o.order_purchase_timestamp,
    o.order_status,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    oi.order_item_id,
    oi.product_id,
    oi.price,
    oi.freight_value,
    s.seller_id,
    s.seller_city,
    s.seller_state
FROM dbo.orders AS o
INNER JOIN dbo.customers AS c
    ON o.customer_id = c.customer_id
INNER JOIN dbo.order_items AS oi
    ON o.order_id = oi.order_id
INNER JOIN dbo.sellers AS s
    ON oi.seller_id = s.seller_id
ORDER BY
    o.order_purchase_timestamp,
    o.order_id,
    oi.order_item_id;

DECLARE @OrderId NVARCHAR(50) = N'0008288aa423d2a3f00fcb17cd7d8719';

SELECT
    oi.order_id,
    oi.order_item_id,
    p.product_id,
    p.product_category_name,
    t.product_category_name_english,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,
    p.product_photos_qty,
    oi.price,
    oi.freight_value
FROM dbo.order_items AS oi
INNER JOIN dbo.products AS p
    ON oi.product_id = p.product_id
LEFT JOIN dbo.product_category_name_translation AS t
    ON p.product_category_name = t.product_category_name
WHERE oi.order_id = @OrderId
ORDER BY oi.order_item_id;

SELECT
    seller_state,
    COUNT(DISTINCT seller_id) AS seller_count
FROM dbo.sellers
WHERE seller_state IS NOT NULL
GROUP BY seller_state
ORDER BY
    seller_count DESC,
    seller_state;

SELECT TOP (10)

    COALESCE(t.product_category_name_english, p.product_category_name, N'未分类') AS product_category,
    COUNT(DISTINCT oi.order_id) AS order_count,
    COUNT_BIG(*) AS item_row_count
FROM dbo.order_items AS oi
INNER JOIN dbo.products AS p
    ON oi.product_id = p.product_id

LEFT JOIN dbo.product_category_name_translation AS t

    ON p.product_category_name = t.product_category_name
GROUP BY
    COALESCE(t.product_category_name_english, p.product_category_name, N'未分类')
ORDER BY
    order_count DESC,
    item_row_count DESC,
    product_category;

SELECT TOP (200)
    o.order_id,
    o.order_purchase_timestamp,
    o.order_status,
    r.review_score,
    r.review_comment_title,
    r.review_comment_message,
    c.customer_city,
    c.customer_state
FROM dbo.order_reviews AS r
INNER JOIN dbo.orders AS o
    ON r.order_id = o.order_id
INNER JOIN dbo.customers AS c
    ON o.customer_id = c.customer_id
WHERE r.review_score < 3
ORDER BY
    r.review_score ASC,
    o.order_purchase_timestamp DESC,
    o.order_id;

SELECT TOP (50)
    s.seller_state,
    COALESCE(t.product_category_name_english, p.product_category_name, N'未分类') AS product_category,
    COUNT(DISTINCT oi.order_id) AS order_count,
    COUNT_BIG(*) AS item_row_count,
    SUM(ISNULL(oi.price, 0)) AS total_item_price,
    SUM(ISNULL(oi.freight_value, 0)) AS total_freight
FROM dbo.order_items AS oi
INNER JOIN dbo.sellers AS s
    ON oi.seller_id = s.seller_id
INNER JOIN dbo.products AS p
    ON oi.product_id = p.product_id
LEFT JOIN dbo.product_category_name_translation AS t
    ON p.product_category_name = t.product_category_name
WHERE s.seller_state = N'SP'
GROUP BY
    s.seller_state,
    COALESCE(t.product_category_name_english, p.product_category_name, N'未分类')
ORDER BY
    order_count DESC,
    item_row_count DESC,
    product_category;

SELECT TOP (100)
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    COUNT_BIG(*) AS five_star_review_count
FROM dbo.order_reviews AS r
INNER JOIN dbo.orders AS o
    ON r.order_id = o.order_id
INNER JOIN dbo.customers AS c
    ON o.customer_id = c.customer_id
WHERE r.review_score = 5
GROUP BY
    c.customer_unique_id,
    c.customer_city,
    c.customer_state
ORDER BY
    five_star_review_count DESC,
    c.customer_state,
    c.customer_city,
    c.customer_unique_id;

SELECT TOP (5)
    s.seller_id,
    s.seller_city,
    s.seller_state,
    COUNT(DISTINCT oi.order_id) AS order_count,
    COUNT_BIG(*) AS item_row_count,
    SUM(ISNULL(oi.price, 0)) AS total_item_price,
    SUM(ISNULL(oi.freight_value, 0)) AS total_freight
FROM dbo.order_items AS oi
INNER JOIN dbo.sellers AS s
    ON oi.seller_id = s.seller_id
GROUP BY
    s.seller_id,
    s.seller_city,
    s.seller_state
ORDER BY
    order_count DESC,
    item_row_count DESC,
    total_item_price DESC,
    s.seller_id;

SELECT
    order_status,
    COUNT_BIG(*) AS order_count
FROM dbo.orders
GROUP BY order_status
ORDER BY
    order_count DESC,
    order_status;

SELECT TOP (20)
    order_id,
    COUNT_BIG(*) AS item_row_count,
    SUM(ISNULL(price, 0)) AS order_items_price,
    SUM(ISNULL(freight_value, 0)) AS order_items_freight
FROM dbo.order_items
GROUP BY order_id
ORDER BY
    item_row_count DESC,
    order_id;

WITH payment_by_order AS
(
    SELECT
        order_id,
        SUM(ISNULL(payment_value, 0)) AS total_payment,
        COUNT_BIG(*) AS payment_row_count
    FROM dbo.order_payments
    GROUP BY order_id
)
SELECT TOP (20)
    o.order_id,
    o.order_purchase_timestamp,
    o.order_status,
    p.payment_row_count,
    p.total_payment
FROM dbo.orders AS o
LEFT JOIN payment_by_order AS p
    ON o.order_id = p.order_id
ORDER BY
    p.total_payment DESC,
    o.order_id;

WITH item_amount_by_order AS
(
    SELECT
        order_id,
        SUM(ISNULL(price, 0)) AS total_item_price,
        SUM(ISNULL(freight_value, 0)) AS total_freight,
        SUM(ISNULL(price, 0) + ISNULL(freight_value, 0)) AS item_amount
    FROM dbo.order_items
    GROUP BY order_id
),
payment_by_order AS
(
    SELECT
        order_id,
        SUM(ISNULL(payment_value, 0)) AS total_payment
    FROM dbo.order_payments
    GROUP BY order_id
)
SELECT TOP (50)
    o.order_id,
    o.order_status,
    i.total_item_price,
    i.total_freight,
    i.item_amount,
    p.total_payment,
    ISNULL(p.total_payment, 0) - ISNULL(i.item_amount, 0) AS payment_minus_item_amount
FROM dbo.orders AS o
LEFT JOIN item_amount_by_order AS i

    ON o.order_id = i.order_id
LEFT JOIN payment_by_order AS p
    ON o.order_id = p.order_id
ORDER BY
    ABS(ISNULL(p.total_payment, 0) - ISNULL(i.item_amount, 0)) DESC,
    o.order_id;

WITH payment_by_order AS
(
    SELECT
        order_id,
        SUM(ISNULL(payment_value, 0)) AS total_payment
    FROM dbo.order_payments
    GROUP BY order_id
)
SELECT
    DATEFROMPARTS(
        YEAR(o.order_purchase_timestamp),
        MONTH(o.order_purchase_timestamp),
        1
    ) AS order_month,
    COUNT_BIG(*) AS order_count,
    SUM(ISNULL(p.total_payment, 0)) AS total_payment
FROM dbo.orders AS o
LEFT JOIN payment_by_order AS p
    ON o.order_id = p.order_id
WHERE o.order_purchase_timestamp IS NOT NULL
GROUP BY
    DATEFROMPARTS(
        YEAR(o.order_purchase_timestamp),
        MONTH(o.order_purchase_timestamp),
        1
    )
ORDER BY order_month;

SELECT TOP (20)
    COALESCE(t.product_category_name_english, p.product_category_name, N'未分类') AS product_category,
    COUNT(DISTINCT oi.order_id) AS order_count,
    COUNT_BIG(*) AS item_row_count,
    SUM(ISNULL(oi.price, 0)) AS total_item_price,
    SUM(ISNULL(oi.freight_value, 0)) AS total_freight,
    AVG(CAST(oi.price AS DECIMAL(18, 2))) AS avg_item_price
FROM dbo.order_items AS oi
INNER JOIN dbo.products AS p
    ON oi.product_id = p.product_id
LEFT JOIN dbo.product_category_name_translation AS t
    ON p.product_category_name = t.product_category_name
GROUP BY
    COALESCE(t.product_category_name_english, p.product_category_name, N'未分类')
ORDER BY
    total_item_price DESC,
    order_count DESC,
    product_category;

SELECT TOP (100)
    s.seller_id,
    s.seller_city,
    s.seller_state,
    COUNT(DISTINCT oi.order_id) AS seller_order_count,
    COUNT_BIG(*) AS seller_item_row_count,
    SUM(ISNULL(oi.price, 0)) AS seller_total_item_price,
    SUM(ISNULL(oi.freight_value, 0)) AS seller_total_freight,
    AVG(CAST(oi.price AS DECIMAL(18, 2))) AS seller_avg_item_price
FROM dbo.sellers AS s
INNER JOIN dbo.order_items AS oi
    ON s.seller_id = oi.seller_id
GROUP BY
    s.seller_id,
    s.seller_city,
    s.seller_state
ORDER BY
    seller_total_item_price DESC,
    seller_order_count DESC,
    s.seller_id;

SELECT TOP (200)
    o.order_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    DATEDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date) AS purchase_to_delivery_days,
    DATEDIFF(DAY, o.order_estimated_delivery_date, o.order_delivered_customer_date) AS estimated_vs_actual_days
FROM dbo.orders AS o
WHERE o.order_purchase_timestamp IS NOT NULL
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
ORDER BY
    estimated_vs_actual_days DESC,
    purchase_to_delivery_days DESC,
    o.order_id;

WITH order_delivery AS
(
    SELECT
        order_id,
        CASE
            WHEN order_delivered_customer_date > order_estimated_delivery_date THEN N'延迟送达'
            ELSE N'未延迟'
        END AS delayed_flag
    FROM dbo.orders
    WHERE order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
),
review_by_order AS
(
    SELECT
        order_id,
        AVG(CAST(review_score AS DECIMAL(10, 2))) AS avg_review_score
    FROM dbo.order_reviews
    WHERE review_score IS NOT NULL
    GROUP BY order_id
)
SELECT
    d.delayed_flag,
    COUNT_BIG(*) AS reviewed_order_count,
    AVG(r.avg_review_score) AS avg_review_score
FROM order_delivery AS d
INNER JOIN review_by_order AS r
    ON d.order_id = r.order_id
GROUP BY d.delayed_flag
ORDER BY d.delayed_flag;

SELECT TOP (50)
    c.customer_state,
    s.seller_state,
    COUNT(DISTINCT oi.order_id) AS order_count,
    COUNT_BIG(*) AS item_row_count,
    SUM(ISNULL(oi.freight_value, 0)) AS total_freight,
    AVG(CAST(oi.freight_value AS DECIMAL(18, 2))) AS avg_freight
FROM dbo.order_items AS oi
INNER JOIN dbo.orders AS o
    ON oi.order_id = o.order_id
INNER JOIN dbo.customers AS c
    ON o.customer_id = c.customer_id
INNER JOIN dbo.sellers AS s
    ON oi.seller_id = s.seller_id
GROUP BY
    c.customer_state,
    s.seller_state
ORDER BY
    order_count DESC,
    item_row_count DESC,
    c.customer_state,
    s.seller_state;
