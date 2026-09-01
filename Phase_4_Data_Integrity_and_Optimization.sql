/*
阶段四：数据完整性与性能优化
概述：建立数据质量报告，补充约束与索引，并创建客户订单、卖家表现等存储过程和商品销售汇总视图，以提升数据可靠性、复用性和查询性能。
*/

USE Olist_Ecommerce_Learning;
GO

SELECT DB_NAME() AS current_database_name;
GO

SELECT
    v.name AS view_name,
    v.create_date,
    v.modify_date
FROM sys.views AS v
WHERE v.name IN
(
    N'v_phase3_order_payment',
    N'v_phase3_customer_summary',
    N'v_phase3_seller_summary',
    N'v_phase3_delivered_order_base'
)
ORDER BY
    v.name;
GO

SELECT N'customers' AS table_name, COUNT_BIG(*) AS row_count FROM dbo.customers
UNION ALL
SELECT N'orders', COUNT_BIG(*) FROM dbo.orders
UNION ALL
SELECT N'order_items', COUNT_BIG(*) FROM dbo.order_items
UNION ALL
SELECT N'order_payments', COUNT_BIG(*) FROM dbo.order_payments
UNION ALL
SELECT N'order_reviews', COUNT_BIG(*) FROM dbo.order_reviews
UNION ALL
SELECT N'products', COUNT_BIG(*) FROM dbo.products
UNION ALL
SELECT N'sellers', COUNT_BIG(*) FROM dbo.sellers
UNION ALL
SELECT N'geolocation', COUNT_BIG(*) FROM dbo.geolocation
ORDER BY
    table_name;
GO

   CREATE OR ALTER VIEW dbo.v_phase4_data_quality_report
AS

SELECT
    N'已送达订单没有客户收货日期' AS check_name,
    N'high' AS severity,
    COUNT_BIG(*) AS issue_count,
    N'order_status = delivered，但 order_delivered_customer_date 为空，物流时效无法计算。' AS explanation
FROM dbo.orders AS o
WHERE
    o.order_status = N'delivered'
    AND o.order_delivered_customer_date IS NULL

UNION ALL

SELECT
    N'已送达订单没有承运商日期',
    N'medium',
    COUNT_BIG(*),
    N'order_status = delivered，但 order_delivered_carrier_date 为空，部分物流拆解指标无法计算。'
FROM dbo.orders AS o
WHERE
    o.order_status = N'delivered'
    AND o.order_delivered_carrier_date IS NULL

UNION ALL

SELECT
    N'订单没有支付记录',
    N'high',
    COUNT_BIG(*),
    N'orders 中存在订单，但 order_payments 中没有对应 order_id，订单实付金额会缺失。'
FROM dbo.orders AS o
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.order_payments AS op
    WHERE op.order_id = o.order_id
)

UNION ALL

SELECT
    N'订单没有商品明细',
    N'high',
    COUNT_BIG(*),
    N'orders 中存在订单，但 order_items 中没有对应 order_id，商品金额和卖家归属会缺失。'
FROM dbo.orders AS o
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.order_items AS oi
    WHERE oi.order_id = o.order_id
)

UNION ALL

SELECT
    N'评分不在 1 到 5',
    N'high',
    COUNT_BIG(*),
    N'review_score 应在 1 到 5 之间；超出范围会影响平均评分。'
FROM dbo.order_reviews AS r
WHERE
    r.review_score IS NOT NULL
    AND (r.review_score < 1 OR r.review_score > 5)

UNION ALL

SELECT
    N'商品价格缺失',
    N'medium',
    COUNT_BIG(*),
    N'price 为空表示价格未知，不应默认改成 0。'
FROM dbo.order_items AS oi
WHERE
    oi.price IS NULL

UNION ALL

SELECT
    N'商品价格为负数',
    N'high',
    COUNT_BIG(*),
    N'price 小于 0，商品交易额会被错误拉低。'
FROM dbo.order_items AS oi
WHERE
    oi.price < 0

UNION ALL

SELECT
    N'运费为负数',
    N'high',
    COUNT_BIG(*),
    N'freight_value 小于 0，物流成本和订单总额会被错误计算。'
FROM dbo.order_items AS oi
WHERE
    oi.freight_value < 0

UNION ALL

SELECT
    N'支付金额为负数',
    N'high',
    COUNT_BIG(*),
    N'payment_value 小于 0，订单实付金额会被错误计算。'
FROM dbo.order_payments AS op
WHERE
    op.payment_value < 0

UNION ALL

SELECT
    N'支付金额缺失',
    N'medium',
    COUNT_BIG(*),
    N'payment_value 为空表示支付金额未知，不应默认改成 0。'
FROM dbo.order_payments AS op
WHERE
    op.payment_value IS NULL

UNION ALL

SELECT
    N'纬度超出 -90 到 90',
    N'high',
    COUNT_BIG(*),
    N'geolocation_lat 超出地球纬度范围，距离计算会失真。'
FROM dbo.geolocation AS g
WHERE
    g.geolocation_lat IS NOT NULL
    AND (g.geolocation_lat < -90 OR g.geolocation_lat > 90)

UNION ALL

SELECT
    N'经度超出 -180 到 180',
    N'high',
    COUNT_BIG(*),
    N'geolocation_lng 超出地球经度范围，距离计算会失真。'
FROM dbo.geolocation AS g
WHERE
    g.geolocation_lng IS NOT NULL
    AND (g.geolocation_lng < -180 OR g.geolocation_lng > 180)

UNION ALL

SELECT
    N'审批时间早于下单时间',
    N'medium',
    COUNT_BIG(*),
    N'order_approved_at 早于 order_purchase_timestamp，订单时间顺序异常。'
FROM dbo.orders AS o
WHERE
    o.order_purchase_timestamp IS NOT NULL
    AND o.order_approved_at IS NOT NULL
    AND o.order_approved_at < o.order_purchase_timestamp

UNION ALL

SELECT
    N'客户收货时间早于下单时间',
    N'high',
    COUNT_BIG(*),
    N'order_delivered_customer_date 早于 order_purchase_timestamp，物流周期会出现负数。'
FROM dbo.orders AS o
WHERE
    o.order_purchase_timestamp IS NOT NULL
    AND o.order_delivered_customer_date IS NOT NULL
    AND o.order_delivered_customer_date < o.order_purchase_timestamp;
GO

SELECT
    check_name,
    severity,
    issue_count,
    explanation
FROM dbo.v_phase4_data_quality_report
ORDER BY
    CASE severity
        WHEN N'high' THEN 1
        WHEN N'medium' THEN 2
        ELSE 3
    END,
    issue_count DESC,
    check_name;
GO

SELECT TOP (50)
    o.order_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date
FROM dbo.orders AS o
WHERE
    o.order_status = N'delivered'
    AND o.order_delivered_customer_date IS NULL
ORDER BY
    o.order_purchase_timestamp;
GO

SELECT TOP (50)
    o.order_id,
    o.order_status,
    o.order_purchase_timestamp
FROM dbo.orders AS o
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.order_payments AS op
    WHERE op.order_id = o.order_id
)
ORDER BY
    o.order_purchase_timestamp;
GO

SELECT TOP (50)
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.price,
    oi.freight_value
FROM dbo.order_items AS oi
WHERE
    oi.price IS NULL
    OR oi.price < 0
    OR oi.freight_value < 0
ORDER BY
    oi.order_id,
    oi.order_item_id;
GO

DECLARE @price_default_constraint_name SYSNAME;
DECLARE @drop_price_default_sql NVARCHAR(MAX);

SELECT
    @price_default_constraint_name = dc.name
FROM sys.default_constraints AS dc
INNER JOIN sys.columns AS c
    ON c.object_id = dc.parent_object_id
    AND c.column_id = dc.parent_column_id
WHERE
    dc.parent_object_id = OBJECT_ID(N'dbo.order_items')
    AND c.name = N'price';

IF @price_default_constraint_name IS NOT NULL
BEGIN
    SET @drop_price_default_sql =
        N'ALTER TABLE dbo.order_items DROP CONSTRAINT '
        + QUOTENAME(@price_default_constraint_name)
        + N';';

    EXEC sys.sp_executesql @drop_price_default_sql;

    PRINT N'已删除 dbo.order_items.price 上的默认约束：' + @price_default_constraint_name;
END
ELSE
BEGIN
    PRINT N'dbo.order_items.price 没有默认约束，不需要删除。';
END;
GO

DROP TRIGGER IF EXISTS dbo.trg_LogProductSales;
GO

DROP TABLE IF EXISTS dbo.product_sales_log;
GO

IF EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE name = N'CK_phase4_order_items_item_sequence_positive'
      AND parent_object_id = OBJECT_ID(N'dbo.order_items')
)
BEGIN
    PRINT N'约束 CK_phase4_order_items_item_sequence_positive 已存在，跳过。';
END
ELSE IF EXISTS
(
    SELECT 1
    FROM dbo.order_items
    WHERE order_item_id <= 0
)
BEGIN
    PRINT N'发现 order_item_id <= 0 的记录，先不添加明细序号正数约束。';
END
ELSE
BEGIN
    ALTER TABLE dbo.order_items WITH CHECK
    ADD CONSTRAINT CK_phase4_order_items_item_sequence_positive
    CHECK (order_item_id > 0);

    PRINT N'已添加约束：order_items.order_item_id 必须大于 0。';
END;
GO

IF EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE name = N'CK_phase4_order_items_price_range'
      AND parent_object_id = OBJECT_ID(N'dbo.order_items')
)
BEGIN
    PRINT N'约束 CK_phase4_order_items_price_range 已存在，跳过。';
END
ELSE IF EXISTS
(
    SELECT 1
    FROM dbo.order_items
    WHERE price < 0 OR price > 100000
)
BEGIN
    PRINT N'发现 price 小于 0 或大于 100000 的记录，先不添加价格范围约束。';
END
ELSE
BEGIN
    ALTER TABLE dbo.order_items WITH CHECK
    ADD CONSTRAINT CK_phase4_order_items_price_range
    CHECK (price IS NULL OR (price >= 0 AND price <= 100000));

    PRINT N'已添加约束：order_items.price 必须为空，或在 0 到 100000 之间。';
END;
GO

IF EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE name = N'CK_phase4_order_items_freight_range'
      AND parent_object_id = OBJECT_ID(N'dbo.order_items')
)
BEGIN
    PRINT N'约束 CK_phase4_order_items_freight_range 已存在，跳过。';
END
ELSE IF EXISTS
(
    SELECT 1
    FROM dbo.order_items
    WHERE freight_value < 0 OR freight_value > 100000
)
BEGIN
    PRINT N'发现 freight_value 小于 0 或大于 100000 的记录，先不添加运费范围约束。';
END
ELSE
BEGIN
    ALTER TABLE dbo.order_items WITH CHECK
    ADD CONSTRAINT CK_phase4_order_items_freight_range
    CHECK (freight_value IS NULL OR (freight_value >= 0 AND freight_value <= 100000));

    PRINT N'已添加约束：order_items.freight_value 必须为空，或在 0 到 100000 之间。';
END;
GO

IF EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE name = N'CK_phase4_order_payments_value_range'
      AND parent_object_id = OBJECT_ID(N'dbo.order_payments')
)
BEGIN
    PRINT N'约束 CK_phase4_order_payments_value_range 已存在，跳过。';
END
ELSE IF EXISTS
(
    SELECT 1
    FROM dbo.order_payments
    WHERE payment_value < 0 OR payment_value > 100000
)
BEGIN
    PRINT N'发现 payment_value 小于 0 或大于 100000 的记录，先不添加支付金额范围约束。';
END
ELSE
BEGIN
    ALTER TABLE dbo.order_payments WITH CHECK
    ADD CONSTRAINT CK_phase4_order_payments_value_range
    CHECK (payment_value IS NULL OR (payment_value >= 0 AND payment_value <= 100000));

    PRINT N'已添加约束：order_payments.payment_value 必须为空，或在 0 到 100000 之间。';
END;
GO

IF EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE name = N'CK_phase4_order_payments_installments_range'
      AND parent_object_id = OBJECT_ID(N'dbo.order_payments')
)
BEGIN
    PRINT N'约束 CK_phase4_order_payments_installments_range 已存在，跳过。';
END
ELSE IF EXISTS
(
    SELECT 1
    FROM dbo.order_payments
    WHERE payment_installments < 0 OR payment_installments > 100
)
BEGIN
    PRINT N'发现 payment_installments 小于 0 或大于 100 的记录，先不添加分期期数范围约束。';
END
ELSE
BEGIN
    ALTER TABLE dbo.order_payments WITH CHECK
    ADD CONSTRAINT CK_phase4_order_payments_installments_range
    CHECK (payment_installments IS NULL OR (payment_installments >= 0 AND payment_installments <= 100));

    PRINT N'已添加约束：order_payments.payment_installments 必须为空，或在 0 到 100 之间。';
END;
GO

IF EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE name = N'CK_phase4_order_reviews_score_range'
      AND parent_object_id = OBJECT_ID(N'dbo.order_reviews')
)
BEGIN
    PRINT N'约束 CK_phase4_order_reviews_score_range 已存在，跳过。';
END
ELSE IF EXISTS
(
    SELECT 1
    FROM dbo.order_reviews
    WHERE review_score < 1 OR review_score > 5
)
BEGIN
    PRINT N'发现 review_score 不在 1 到 5 的记录，先不添加评分范围约束。';
END
ELSE
BEGIN
    ALTER TABLE dbo.order_reviews WITH CHECK
    ADD CONSTRAINT CK_phase4_order_reviews_score_range
    CHECK (review_score IS NULL OR (review_score BETWEEN 1 AND 5));

    PRINT N'已添加约束：order_reviews.review_score 必须为空，或在 1 到 5 之间。';
END;
GO

IF EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE name = N'CK_phase4_geolocation_lat_range'
      AND parent_object_id = OBJECT_ID(N'dbo.geolocation')
)
BEGIN
    PRINT N'约束 CK_phase4_geolocation_lat_range 已存在，跳过。';
END
ELSE IF EXISTS
(
    SELECT 1
    FROM dbo.geolocation
    WHERE geolocation_lat < -90 OR geolocation_lat > 90
)
BEGIN
    PRINT N'发现 geolocation_lat 超出 -90 到 90 的记录，先不添加纬度范围约束。';
END
ELSE
BEGIN
    ALTER TABLE dbo.geolocation WITH CHECK
    ADD CONSTRAINT CK_phase4_geolocation_lat_range
    CHECK (geolocation_lat IS NULL OR (geolocation_lat BETWEEN -90 AND 90));

    PRINT N'已添加约束：geolocation.geolocation_lat 必须为空，或在 -90 到 90 之间。';
END;
GO

IF EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE name = N'CK_phase4_geolocation_lng_range'
      AND parent_object_id = OBJECT_ID(N'dbo.geolocation')
)
BEGIN
    PRINT N'约束 CK_phase4_geolocation_lng_range 已存在，跳过。';
END
ELSE IF EXISTS
(
    SELECT 1
    FROM dbo.geolocation
    WHERE geolocation_lng < -180 OR geolocation_lng > 180
)
BEGIN
    PRINT N'发现 geolocation_lng 超出 -180 到 180 的记录，先不添加经度范围约束。';
END
ELSE
BEGIN
    ALTER TABLE dbo.geolocation WITH CHECK
    ADD CONSTRAINT CK_phase4_geolocation_lng_range
    CHECK (geolocation_lng IS NULL OR (geolocation_lng BETWEEN -180 AND 180));

    PRINT N'已添加约束：geolocation.geolocation_lng 必须为空，或在 -180 到 180 之间。';
END;
GO

IF EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE name = N'CK_phase4_orders_delivery_after_purchase'
      AND parent_object_id = OBJECT_ID(N'dbo.orders')
)
BEGIN
    PRINT N'约束 CK_phase4_orders_delivery_after_purchase 已存在，跳过。';
END
ELSE IF EXISTS
(
    SELECT 1
    FROM dbo.orders
    WHERE order_purchase_timestamp IS NOT NULL
      AND order_delivered_customer_date IS NOT NULL
      AND order_delivered_customer_date < order_purchase_timestamp
)
BEGIN
    PRINT N'发现客户收货时间早于下单时间的记录，先不添加订单日期顺序约束。';
END
ELSE
BEGIN
    ALTER TABLE dbo.orders WITH CHECK
    ADD CONSTRAINT CK_phase4_orders_delivery_after_purchase
    CHECK
    (
        order_delivered_customer_date IS NULL
        OR order_purchase_timestamp IS NULL
        OR order_delivered_customer_date >= order_purchase_timestamp
    );

    PRINT N'已添加约束：客户收货时间不能早于下单时间。';
END;
GO

SELECT
    t.name AS table_name,
    cc.name AS constraint_name,
    cc.is_disabled,
    cc.is_not_trusted,
    cc.definition
FROM sys.check_constraints AS cc
INNER JOIN sys.tables AS t
    ON t.object_id = cc.parent_object_id
WHERE
    cc.name LIKE N'CK_phase4%'
ORDER BY
    t.name,
    cc.name;
GO

   SELECT
    t.name AS table_name,
    i.name AS index_name,
    i.type_desc,
    i.is_primary_key,
    i.is_unique,

    STUFF
    (
        (
            SELECT
                N', ' + c.name
            FROM sys.index_columns AS ic
            INNER JOIN sys.columns AS c
                ON c.object_id = ic.object_id
                AND c.column_id = ic.column_id
            WHERE
                ic.object_id = i.object_id
                AND ic.index_id = i.index_id
                AND ic.key_ordinal > 0
            ORDER BY
                ic.key_ordinal
            FOR XML PATH(N''), TYPE
        ).value(N'.', N'NVARCHAR(MAX)'),
        1,
        2,
        N''
    ) AS key_columns,

    STUFF
    (
        (
            SELECT
                N', ' + c.name
            FROM sys.index_columns AS ic
            INNER JOIN sys.columns AS c
                ON c.object_id = ic.object_id
                AND c.column_id = ic.column_id
            WHERE
                ic.object_id = i.object_id
                AND ic.index_id = i.index_id
                AND ic.is_included_column = 1
            ORDER BY
                c.name
            FOR XML PATH(N''), TYPE
        ).value(N'.', N'NVARCHAR(MAX)'),
        1,
        2,
        N''
    ) AS included_columns
FROM sys.indexes AS i
INNER JOIN sys.tables AS t
    ON t.object_id = i.object_id
WHERE
    t.name IN
    (
        N'customers',
        N'orders',
        N'order_items',
        N'order_payments',
        N'order_reviews',
        N'products',
        N'sellers',
        N'geolocation'
    )
    AND i.name IS NOT NULL
ORDER BY
    t.name,
    i.name;
GO

IF EXISTS
(
    SELECT 1
    FROM sys.indexes AS i
    INNER JOIN sys.index_columns AS ic
        ON ic.object_id = i.object_id
        AND ic.index_id = i.index_id
        AND ic.key_ordinal = 1
    INNER JOIN sys.columns AS c
        ON c.object_id = ic.object_id
        AND c.column_id = ic.column_id
    WHERE
        i.object_id = OBJECT_ID(N'dbo.customers')
        AND c.name = N'customer_unique_id'
)
BEGIN
    PRINT N'dbo.customers 已有以 customer_unique_id 开头的索引，跳过新增。';
END
ELSE
BEGIN
    CREATE INDEX IX_phase4_customers_unique_id
    ON dbo.customers (customer_unique_id)
    INCLUDE (customer_id);

    PRINT N'已创建索引 IX_phase4_customers_unique_id。';
END;
GO

IF EXISTS
(
    SELECT 1
    FROM sys.indexes AS i
    INNER JOIN sys.index_columns AS ic1
        ON ic1.object_id = i.object_id
        AND ic1.index_id = i.index_id
        AND ic1.key_ordinal = 1
    INNER JOIN sys.columns AS c1
        ON c1.object_id = ic1.object_id
        AND c1.column_id = ic1.column_id
    INNER JOIN sys.index_columns AS ic2
        ON ic2.object_id = i.object_id
        AND ic2.index_id = i.index_id
        AND ic2.key_ordinal = 2
    INNER JOIN sys.columns AS c2
        ON c2.object_id = ic2.object_id
        AND c2.column_id = ic2.column_id
    WHERE
        i.object_id = OBJECT_ID(N'dbo.orders')
        AND c1.name = N'order_status'
        AND c2.name = N'order_purchase_timestamp'
)
BEGIN
    PRINT N'dbo.orders 已有以 order_status, order_purchase_timestamp 开头的索引，跳过新增。';
END
ELSE
BEGIN
    CREATE INDEX IX_phase4_orders_status_purchase
    ON dbo.orders (order_status, order_purchase_timestamp)
    INCLUDE
    (
        customer_id,
        order_delivered_customer_date,
        order_estimated_delivery_date
    );

    PRINT N'已创建索引 IX_phase4_orders_status_purchase。';
END;
GO

IF EXISTS
(
    SELECT 1
    FROM sys.indexes AS i
    INNER JOIN sys.index_columns AS ic1
        ON ic1.object_id = i.object_id
        AND ic1.index_id = i.index_id
        AND ic1.key_ordinal = 1
    INNER JOIN sys.columns AS c1
        ON c1.object_id = ic1.object_id
        AND c1.column_id = ic1.column_id
    INNER JOIN sys.index_columns AS ic2
        ON ic2.object_id = i.object_id
        AND ic2.index_id = i.index_id
        AND ic2.key_ordinal = 2
    INNER JOIN sys.columns AS c2
        ON c2.object_id = ic2.object_id
        AND c2.column_id = ic2.column_id
    WHERE
        i.object_id = OBJECT_ID(N'dbo.order_items')
        AND c1.name = N'seller_id'
        AND c2.name = N'order_id'
)
BEGIN
    PRINT N'dbo.order_items 已有以 seller_id, order_id 开头的索引，跳过新增。';
END
ELSE
BEGIN
    CREATE INDEX IX_phase4_order_items_seller_order
    ON dbo.order_items (seller_id, order_id)
    INCLUDE
    (
        product_id,
        price,
        freight_value
    );

    PRINT N'已创建索引 IX_phase4_order_items_seller_order。';
END;
GO

   CREATE OR ALTER PROCEDURE dbo.usp_phase4_get_customer_order_history
    @customer_unique_id NVARCHAR(50)
AS
BEGIN

    SET NOCOUNT ON;

    IF @customer_unique_id IS NULL OR LTRIM(RTRIM(@customer_unique_id)) = N''
    BEGIN
        RAISERROR(N'请传入 customer_unique_id。不要使用 customer_id 查询真实客户历史。', 16, 1);
        RETURN;
    END;

    SELECT
        c.customer_unique_id,
        c.customer_id,
        c.customer_city,
        c.customer_state,

        o.order_id,
        o.order_status,
        o.order_purchase_timestamp,
        o.order_approved_at,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,

        op.payment_record_count,
        op.payment_type_count,
        op.max_payment_installments,
        op.total_payment_value,

        oi.order_item_id AS item_sequence_in_order,
        oi.product_id,
        p.product_category_name,
        pct.product_category_name_english,
        oi.seller_id,
        oi.price,
        oi.freight_value,
        oi.shipping_limit_date
    FROM dbo.customers AS c
    INNER JOIN dbo.orders AS o
        ON o.customer_id = c.customer_id
    LEFT JOIN dbo.v_phase3_order_payment AS op
        ON op.order_id = o.order_id
    LEFT JOIN dbo.order_items AS oi
        ON oi.order_id = o.order_id
    LEFT JOIN dbo.products AS p
        ON p.product_id = oi.product_id
    LEFT JOIN dbo.product_category_name_translation AS pct
        ON pct.product_category_name = p.product_category_name
    WHERE
        c.customer_unique_id = @customer_unique_id
    ORDER BY
        o.order_purchase_timestamp DESC,
        o.order_id,
        oi.order_item_id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_phase4_get_seller_performance
    @seller_id NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    IF @seller_id IS NULL OR LTRIM(RTRIM(@seller_id)) = N''
    BEGIN
        RAISERROR(N'请传入 seller_id。', 16, 1);
        RETURN;
    END;

    SELECT
        ss.seller_id,
        ss.seller_city,
        ss.seller_state,
        ss.delivered_order_count,
        ss.buyer_count,
        ss.seller_item_row_count,
        ss.seller_product_gmv,
        ss.seller_freight_value,
        ss.avg_review_score,
        ss.reviewed_order_count,
        ss.avg_delivery_days,
        ss.late_delivery_rate,

        ss.seller_product_gmv / NULLIF(CAST(ss.delivered_order_count AS DECIMAL(18, 2)), 0)
            AS avg_product_gmv_per_delivered_order
    FROM dbo.v_phase3_seller_summary AS ss
    WHERE
        ss.seller_id = @seller_id;
END;
GO

DECLARE @sample_customer_unique_id NVARCHAR(50);

SELECT TOP (1)
    @sample_customer_unique_id = cs.customer_unique_id
FROM dbo.v_phase3_customer_summary AS cs
ORDER BY
    cs.delivered_order_count DESC,
    cs.total_payment_value DESC;

EXEC dbo.usp_phase4_get_customer_order_history
    @customer_unique_id = @sample_customer_unique_id;
GO

DECLARE @sample_seller_id NVARCHAR(50);

SELECT TOP (1)
    @sample_seller_id = ss.seller_id
FROM dbo.v_phase3_seller_summary AS ss
ORDER BY
    ss.seller_product_gmv DESC;

EXEC dbo.usp_phase4_get_seller_performance
    @seller_id = @sample_seller_id;
GO

CREATE OR ALTER VIEW dbo.v_phase4_product_sales_summary
AS
SELECT
    oi.product_id,
    p.product_category_name,
    pct.product_category_name_english,

    COUNT_BIG(*) AS sold_item_row_count,

    COUNT(DISTINCT oi.order_id) AS delivered_order_count,

    COUNT(DISTINCT oi.seller_id) AS seller_count,

    COUNT(oi.price) AS price_known_row_count,
    COUNT_BIG(*) - COUNT(oi.price) AS price_missing_row_count,

    SUM(oi.price) AS product_gmv_known_price_only,
    SUM(oi.freight_value) AS freight_value_known_only,

    MIN(o.order_purchase_timestamp) AS first_purchase_time,
    MAX(o.order_purchase_timestamp) AS last_purchase_time
FROM dbo.order_items AS oi
INNER JOIN dbo.orders AS o
    ON o.order_id = oi.order_id
LEFT JOIN dbo.products AS p
    ON p.product_id = oi.product_id
LEFT JOIN dbo.product_category_name_translation AS pct
    ON pct.product_category_name = p.product_category_name
WHERE
    o.order_status = N'delivered'
GROUP BY
    oi.product_id,
    p.product_category_name,
    pct.product_category_name_english;
GO

SELECT TOP (50)
    pss.product_id,
    pss.product_category_name,
    pss.product_category_name_english,
    pss.sold_item_row_count,
    pss.delivered_order_count,
    pss.seller_count,
    pss.price_known_row_count,
    pss.price_missing_row_count,
    pss.product_gmv_known_price_only,
    pss.freight_value_known_only,
    pss.first_purchase_time,
    pss.last_purchase_time
FROM dbo.v_phase4_product_sales_summary AS pss
ORDER BY
    pss.sold_item_row_count DESC,
    pss.product_gmv_known_price_only DESC;
GO

SELECT
    o.name AS object_name,
    o.type_desc,
    o.create_date,
    o.modify_date
FROM sys.objects AS o
WHERE
    o.name LIKE N'v_phase4%'
    OR o.name LIKE N'usp_phase4%'
ORDER BY
    o.type_desc,
    o.name;
GO

SELECT
    check_name,
    severity,
    issue_count,
    explanation
FROM dbo.v_phase4_data_quality_report
ORDER BY
    CASE severity
        WHEN N'high' THEN 1
        WHEN N'medium' THEN 2
        ELSE 3
    END,
    issue_count DESC,
    check_name;
GO

SELECT
    t.name AS table_name,
    i.name AS index_name,
    i.type_desc,
    i.is_unique,
    i.is_primary_key
FROM sys.indexes AS i
INNER JOIN sys.tables AS t
    ON t.object_id = i.object_id
WHERE
    i.name LIKE N'IX_phase4%'
ORDER BY
    t.name,
    i.name;
GO

SELECT
    t.name AS table_name,
    cc.name AS constraint_name,
    cc.definition
FROM sys.check_constraints AS cc
INNER JOIN sys.tables AS t
    ON t.object_id = cc.parent_object_id
WHERE
    cc.name LIKE N'CK_phase4%'
ORDER BY
    t.name,
    cc.name;
GO

SELECT TOP (10)
    *
FROM dbo.v_phase4_product_sales_summary
ORDER BY
    sold_item_row_count DESC;
GO
