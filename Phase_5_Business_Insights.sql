/*
阶段五：商业洞察
概述：围绕经营 KPI、品类与区域销售、同比与趋势预测、RFM、CLV、客户流失、商家分层与留存、物流风险及交叉销售构建 Power BI 所需的业务视图。
*/

USE Olist_Ecommerce_Learning;
GO

SELECT DB_NAME() AS current_database_name;
GO

WITH required_objects AS
(
    SELECT N'v_phase3_delivered_order_base' AS object_name

    UNION ALL SELECT N'v_phase3_customer_summary'

    UNION ALL SELECT N'v_phase3_seller_summary'

    UNION ALL SELECT N'v_phase3_seller_order_analysis'
    UNION ALL SELECT N'v_phase3_logistics_state_flow'
    UNION ALL SELECT N'v_phase4_data_quality_report'
    UNION ALL SELECT N'v_phase4_product_sales_summary'
)

SELECT

    ro.object_name,

    CASE

        WHEN o.object_id IS NULL THEN 0

        ELSE 1
    END AS required_object_exists,

    o.type_desc,

    o.modify_date

FROM required_objects AS ro

LEFT JOIN sys.objects AS o

    ON o.object_id = OBJECT_ID(N'dbo.' + ro.object_name)

ORDER BY
    ro.object_name;
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

CREATE OR ALTER VIEW dbo.v_phase5_kpi_snapshot
AS
SELECT
    COUNT_BIG(*) AS delivered_order_count,
    COUNT(DISTINCT dob.customer_unique_id) AS buyer_count,

    (
        SELECT COUNT_BIG(*)
        FROM dbo.v_phase3_seller_summary AS ss
    ) AS seller_count,

    SUM(dob.total_payment_value) AS total_payment_value,
    SUM(dob.product_gmv) AS product_gmv,
    SUM(dob.freight_value) AS freight_value,
    AVG(CAST(dob.total_payment_value AS DECIMAL(18, 2))) AS avg_payment_per_order,
    AVG(CAST(dob.product_gmv AS DECIMAL(18, 2))) AS avg_product_gmv_per_order,
    AVG(CAST(dob.avg_review_score AS DECIMAL(10, 2))) AS avg_review_score,
    AVG(CAST(dob.purchase_to_delivery_days AS DECIMAL(10, 2))) AS avg_delivery_days,
    AVG(CAST(dob.late_delivery_flag AS DECIMAL(10, 4))) AS late_delivery_rate,
    MIN(dob.order_purchase_timestamp) AS first_order_time,
    MAX(dob.order_purchase_timestamp) AS last_order_time
FROM dbo.v_phase3_delivered_order_base AS dob;
GO

SELECT *
FROM dbo.v_phase5_kpi_snapshot;
GO

CREATE OR ALTER VIEW dbo.v_phase5_category_seller_region_gmv
AS
SELECT

    COALESCE(p.product_category_name, N'unknown') AS product_category_name,

    COALESCE(pct.product_category_name_english, p.product_category_name, N'unknown') AS product_category_name_english,
    oi.seller_id,
    s.seller_state,
    s.seller_city,
    c.customer_state AS customer_region,
    COUNT_BIG(*) AS sold_item_row_count,
    COUNT(DISTINCT oi.order_id) AS delivered_order_count,
    COUNT(DISTINCT c.customer_unique_id) AS buyer_count,
    SUM(oi.price) AS product_gmv,
    SUM(oi.freight_value) AS freight_value,
    AVG(CAST(oi.price AS DECIMAL(18, 2))) AS avg_item_price
FROM dbo.order_items AS oi

INNER JOIN dbo.orders AS o
    ON o.order_id = oi.order_id
INNER JOIN dbo.customers AS c
    ON c.customer_id = o.customer_id

LEFT JOIN dbo.sellers AS s
    ON s.seller_id = oi.seller_id
LEFT JOIN dbo.products AS p
    ON p.product_id = oi.product_id
LEFT JOIN dbo.product_category_name_translation AS pct
    ON pct.product_category_name = p.product_category_name
WHERE
    o.order_status = N'delivered'
GROUP BY
    COALESCE(p.product_category_name, N'unknown'),
    COALESCE(pct.product_category_name_english, p.product_category_name, N'unknown'),
    oi.seller_id,
    s.seller_state,
    s.seller_city,
    c.customer_state;
GO

SELECT TOP (100)
    product_category_name_english,
    seller_id,
    seller_state,
    customer_region,
    sold_item_row_count,
    delivered_order_count,
    buyer_count,
    product_gmv,
    freight_value,
    avg_item_price
FROM dbo.v_phase5_category_seller_region_gmv
ORDER BY
    product_gmv DESC,
    sold_item_row_count DESC;
GO

CREATE OR ALTER VIEW dbo.v_phase5_monthly_category_gmv
AS
SELECT
    YEAR(o.order_purchase_timestamp) AS order_year,
    MONTH(o.order_purchase_timestamp) AS order_month,

    DATEFROMPARTS
    (
        YEAR(o.order_purchase_timestamp),
        MONTH(o.order_purchase_timestamp),
        1
    ) AS order_month_start,
    COALESCE(p.product_category_name, N'unknown') AS product_category_name,
    COALESCE(pct.product_category_name_english, p.product_category_name, N'unknown') AS product_category_name_english,
    COUNT_BIG(*) AS sold_item_row_count,
    COUNT(DISTINCT oi.order_id) AS delivered_order_count,
    SUM(oi.price) AS product_gmv,
    SUM(oi.freight_value) AS freight_value
FROM dbo.order_items AS oi
INNER JOIN dbo.orders AS o
    ON o.order_id = oi.order_id
LEFT JOIN dbo.products AS p
    ON p.product_id = oi.product_id
LEFT JOIN dbo.product_category_name_translation AS pct
    ON pct.product_category_name = p.product_category_name
WHERE
    o.order_status = N'delivered'
    AND o.order_purchase_timestamp IS NOT NULL
GROUP BY
    YEAR(o.order_purchase_timestamp),
    MONTH(o.order_purchase_timestamp),
    DATEFROMPARTS
    (
        YEAR(o.order_purchase_timestamp),
        MONTH(o.order_purchase_timestamp),
        1
    ),
    COALESCE(p.product_category_name, N'unknown'),
    COALESCE(pct.product_category_name_english, p.product_category_name, N'unknown');
GO

SELECT TOP (100)
    order_month_start,
    product_category_name_english,
    sold_item_row_count,
    delivered_order_count,
    product_gmv,
    freight_value
FROM dbo.v_phase5_monthly_category_gmv
ORDER BY
    order_month_start,
    product_gmv DESC;
GO

CREATE OR ALTER VIEW dbo.v_phase5_monthly_business_trend
AS
SELECT
    dob.order_year,
    dob.order_month,
    dob.order_month_start,
    COUNT_BIG(*) AS delivered_order_count,
    COUNT(DISTINCT dob.customer_unique_id) AS buyer_count,
    SUM(dob.total_payment_value) AS total_payment_value,
    SUM(dob.product_gmv) AS product_gmv,
    SUM(dob.freight_value) AS freight_value,
    AVG(CAST(dob.total_payment_value AS DECIMAL(18, 2))) AS avg_payment_per_order,
    AVG(CAST(dob.avg_review_score AS DECIMAL(10, 2))) AS avg_review_score,
    AVG(CAST(dob.purchase_to_delivery_days AS DECIMAL(10, 2))) AS avg_delivery_days,
    AVG(CAST(dob.late_delivery_flag AS DECIMAL(10, 4))) AS late_delivery_rate
FROM dbo.v_phase3_delivered_order_base AS dob
WHERE
    dob.order_month_start IS NOT NULL
GROUP BY
    dob.order_year,
    dob.order_month,
    dob.order_month_start;
GO

SELECT
    order_month_start,
    delivered_order_count,
    buyer_count,
    total_payment_value,
    product_gmv,
    avg_payment_per_order,
    late_delivery_rate
FROM dbo.v_phase5_monthly_business_trend
ORDER BY
    order_month_start;
GO

CREATE OR ALTER VIEW dbo.v_phase5_yoy_growth
AS
WITH yearly_business AS
(
    SELECT
        dob.order_year,
        COUNT_BIG(*) AS delivered_order_count,
        SUM(dob.total_payment_value) AS total_payment_value,
        SUM(dob.product_gmv) AS product_gmv
    FROM dbo.v_phase3_delivered_order_base AS dob
    WHERE
        dob.order_year IS NOT NULL
    GROUP BY
        dob.order_year
),
yearly_with_lag AS
(
    SELECT
        yb.order_year,
        yb.delivered_order_count,
        yb.total_payment_value,
        yb.product_gmv,

        LAG(yb.total_payment_value) OVER (ORDER BY yb.order_year) AS previous_year_payment_value,
        LAG(yb.product_gmv) OVER (ORDER BY yb.order_year) AS previous_year_product_gmv
    FROM yearly_business AS yb
)
SELECT
    order_year,
    delivered_order_count,
    total_payment_value,
    previous_year_payment_value,
    ROUND
    (
        100.0 * (total_payment_value - previous_year_payment_value)
        / NULLIF(previous_year_payment_value, 0),
        2
    ) AS payment_yoy_growth_rate_percent,
    product_gmv,
    previous_year_product_gmv,
    ROUND
    (
        100.0 * (product_gmv - previous_year_product_gmv)
        / NULLIF(previous_year_product_gmv, 0),
        2
    ) AS product_gmv_yoy_growth_rate_percent
FROM yearly_with_lag;
GO

SELECT *
FROM dbo.v_phase5_yoy_growth
ORDER BY
    order_year;
GO

CREATE OR ALTER VIEW dbo.v_phase5_weekday_vs_weekend
AS
WITH order_weekday AS
(
    SELECT
        dob.order_id,
        dob.customer_unique_id,
        dob.total_payment_value,
        dob.product_gmv,
        dob.order_purchase_timestamp,
        (
            DATEDIFF
            (
                DAY,
                CONVERT(date, '19000101'),
                CAST(dob.order_purchase_timestamp AS date)
            ) % 7
        ) AS weekday_index_monday_0
    FROM dbo.v_phase3_delivered_order_base AS dob
    WHERE
        dob.order_purchase_timestamp IS NOT NULL
)
SELECT
    weekday_index_monday_0 + 1 AS weekday_number_monday_1,

    CASE weekday_index_monday_0
        WHEN 0 THEN N'Monday'
        WHEN 1 THEN N'Tuesday'
        WHEN 2 THEN N'Wednesday'
        WHEN 3 THEN N'Thursday'
        WHEN 4 THEN N'Friday'
        WHEN 5 THEN N'Saturday'
        WHEN 6 THEN N'Sunday'
    END AS weekday_name_en,
    CASE
        WHEN weekday_index_monday_0 IN (5, 6) THEN N'Weekend'
        ELSE N'Weekday'
    END AS day_type,
    COUNT_BIG(*) AS delivered_order_count,
    COUNT(DISTINCT customer_unique_id) AS buyer_count,
    SUM(total_payment_value) AS total_payment_value,
    SUM(product_gmv) AS product_gmv,
    AVG(CAST(total_payment_value AS DECIMAL(18, 2))) AS avg_payment_per_order
FROM order_weekday
GROUP BY
    weekday_index_monday_0,
    CASE weekday_index_monday_0
        WHEN 0 THEN N'Monday'
        WHEN 1 THEN N'Tuesday'
        WHEN 2 THEN N'Wednesday'
        WHEN 3 THEN N'Thursday'
        WHEN 4 THEN N'Friday'
        WHEN 5 THEN N'Saturday'
        WHEN 6 THEN N'Sunday'
    END,
    CASE
        WHEN weekday_index_monday_0 IN (5, 6) THEN N'Weekend'
        ELSE N'Weekday'
    END;
GO

SELECT *
FROM dbo.v_phase5_weekday_vs_weekend
ORDER BY
    weekday_number_monday_1;
GO

CREATE OR ALTER VIEW dbo.v_phase5_customer_value_tiers
AS
WITH customer_scored AS
(
    SELECT
        cs.*,
        NTILE(4) OVER (ORDER BY cs.total_payment_value) AS payment_quartile,
        NTILE(4) OVER (ORDER BY cs.delivered_order_count) AS frequency_quartile,

        NTILE(4) OVER (ORDER BY ISNULL(cs.avg_review_score, 0)) AS review_quartile
    FROM dbo.v_phase3_customer_summary AS cs
)
SELECT
    customer_unique_id,
    delivered_order_count,
    total_payment_value,
    product_gmv,
    freight_value,
    avg_payment_per_order,
    first_purchase_time,
    last_purchase_time,
    customer_lifetime_days,
    avg_review_score,
    late_delivery_rate,
    payment_quartile,
    frequency_quartile,
    review_quartile,
    CASE
        WHEN payment_quartile = 4 AND frequency_quartile >= 3 THEN N'高价值复购客户'
        WHEN payment_quartile = 4 THEN N'高客单价值客户'
        WHEN frequency_quartile = 4 THEN N'高频客户'
        WHEN payment_quartile = 1 AND frequency_quartile = 1 THEN N'低活跃低消费客户'
        ELSE N'普通客户'
    END AS customer_value_tier
FROM customer_scored;
GO

SELECT TOP (100)
    customer_unique_id,
    customer_value_tier,
    delivered_order_count,
    total_payment_value,
    avg_payment_per_order,
    first_purchase_time,
    last_purchase_time
FROM dbo.v_phase5_customer_value_tiers
ORDER BY
    total_payment_value DESC;
GO

CREATE OR ALTER VIEW dbo.v_phase5_customer_rfm
AS
WITH analysis_date AS
(
    SELECT
        DATEADD(DAY, 1, MAX(order_purchase_timestamp)) AS snapshot_date
    FROM dbo.v_phase3_delivered_order_base
),
rfm_base AS
(
    SELECT
        cs.customer_unique_id,
        DATEDIFF(DAY, cs.last_purchase_time, ad.snapshot_date) AS recency_days,
        cs.delivered_order_count AS frequency_orders,
        cs.total_payment_value AS monetary_value,
        cs.avg_payment_per_order,
        cs.first_purchase_time,
        cs.last_purchase_time,
        ad.snapshot_date
    FROM dbo.v_phase3_customer_summary AS cs
    CROSS JOIN analysis_date AS ad
),
rfm_scored AS
(
    SELECT
        rb.*,

        NTILE(5) OVER (ORDER BY rb.recency_days DESC) AS recency_score,

        NTILE(5) OVER (ORDER BY rb.frequency_orders) AS frequency_score,
        NTILE(5) OVER (ORDER BY rb.monetary_value) AS monetary_score
    FROM rfm_base AS rb
)
SELECT
    customer_unique_id,
    snapshot_date,
    recency_days,
    frequency_orders,
    monetary_value,
    avg_payment_per_order,
    first_purchase_time,
    last_purchase_time,
    recency_score,
    frequency_score,
    monetary_score,
    recency_score + frequency_score + monetary_score AS rfm_total_score,
    CONCAT(recency_score, frequency_score, monetary_score) AS rfm_code,
    CASE
        WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4
            THEN N'最佳客户'
        WHEN recency_score >= 4 AND frequency_score >= 3
            THEN N'忠诚客户'
        WHEN recency_score >= 4 AND monetary_score >= 4
            THEN N'近期高消费客户'
        WHEN recency_score <= 2 AND frequency_score >= 3
            THEN N'需要唤醒的老客户'
        WHEN recency_score = 1
            THEN N'可能流失客户'
        ELSE N'普通客户'
    END AS rfm_segment
FROM rfm_scored;
GO

SELECT TOP (100)
    customer_unique_id,
    rfm_segment,
    recency_days,
    frequency_orders,
    monetary_value,
    recency_score,
    frequency_score,
    monetary_score,
    rfm_total_score,
    rfm_code
FROM dbo.v_phase5_customer_rfm
ORDER BY
    rfm_total_score DESC,
    monetary_value DESC;
GO

CREATE OR ALTER VIEW dbo.v_phase5_customer_clv
AS
WITH clv_base AS
(
    SELECT
        cs.customer_unique_id,
        cs.delivered_order_count,
        cs.total_payment_value,
        cs.avg_payment_per_order,
        cs.first_purchase_time,
        cs.last_purchase_time,
        cs.customer_lifetime_days,

        CASE
            WHEN cs.customer_lifetime_days IS NULL OR cs.customer_lifetime_days < 30
                THEN CAST(1.0 AS DECIMAL(18, 4))
            ELSE CAST(cs.customer_lifetime_days AS DECIMAL(18, 4)) / 30.0
        END AS active_months
    FROM dbo.v_phase3_customer_summary AS cs
),
clv_calculated AS
(
    SELECT
        cb.*,
        CAST(cb.delivered_order_count AS DECIMAL(18, 4)) / NULLIF(cb.active_months, 0)
            AS purchase_frequency_per_month,
        cb.avg_payment_per_order
            * CAST(cb.delivered_order_count AS DECIMAL(18, 4))
            / NULLIF(cb.active_months, 0)
            AS estimated_monthly_value,
        cb.avg_payment_per_order
            * CAST(cb.delivered_order_count AS DECIMAL(18, 4))
            / NULLIF(cb.active_months, 0)
            * 12.0
            AS clv_12m_estimate
    FROM clv_base AS cb
),
clv_scored AS
(
    SELECT
        cc.*,
        NTILE(4) OVER (ORDER BY cc.clv_12m_estimate) AS clv_quartile
    FROM clv_calculated AS cc
)
SELECT
    customer_unique_id,
    delivered_order_count,
    total_payment_value,
    avg_payment_per_order,
    first_purchase_time,
    last_purchase_time,
    customer_lifetime_days,
    active_months,
    purchase_frequency_per_month,
    estimated_monthly_value,
    clv_12m_estimate,
    clv_quartile,
    CASE
        WHEN clv_quartile = 4 THEN N'高 CLV 客户'
        WHEN clv_quartile = 3 THEN N'中高 CLV 客户'
        WHEN clv_quartile = 2 THEN N'中低 CLV 客户'
        ELSE N'低 CLV 客户'
    END AS clv_segment
FROM clv_scored;
GO

SELECT TOP (100)
    customer_unique_id,
    clv_segment,
    delivered_order_count,
    total_payment_value,
    avg_payment_per_order,
    active_months,
    clv_12m_estimate
FROM dbo.v_phase5_customer_clv
ORDER BY
    clv_12m_estimate DESC;
GO

CREATE OR ALTER VIEW dbo.v_phase5_customer_churn
AS
WITH analysis_date AS
(
    SELECT
        DATEADD(DAY, 1, MAX(order_purchase_timestamp)) AS snapshot_date
    FROM dbo.v_phase3_delivered_order_base
)
SELECT
    cs.customer_unique_id,
    cs.delivered_order_count,
    cs.total_payment_value,
    cs.first_purchase_time,
    cs.last_purchase_time,
    ad.snapshot_date,
    DATEDIFF(DAY, cs.last_purchase_time, ad.snapshot_date) AS days_since_last_order,
    CASE
        WHEN DATEDIFF(DAY, cs.last_purchase_time, ad.snapshot_date) > 180
            THEN N'可能流失'
        WHEN DATEDIFF(DAY, cs.last_purchase_time, ad.snapshot_date) BETWEEN 90 AND 180
            THEN N'流失风险'
        ELSE N'活跃'
    END AS churn_status
FROM dbo.v_phase3_customer_summary AS cs
CROSS JOIN analysis_date AS ad;
GO

SELECT
    churn_status,
    COUNT_BIG(*) AS customer_count,
    SUM(total_payment_value) AS total_payment_value,
    AVG(CAST(days_since_last_order AS DECIMAL(18, 2))) AS avg_days_since_last_order
FROM dbo.v_phase5_customer_churn
GROUP BY
    churn_status
ORDER BY
    customer_count DESC;
GO

CREATE OR ALTER VIEW dbo.v_phase5_region_delivery_insight
AS
SELECT
    dob.customer_state AS customer_region,
    COUNT_BIG(*) AS delivered_order_count,
    COUNT(DISTINCT dob.customer_unique_id) AS buyer_count,
    SUM(dob.total_payment_value) AS total_payment_value,
    SUM(dob.product_gmv) AS product_gmv,
    AVG(CAST(dob.purchase_to_delivery_days AS DECIMAL(10, 2))) AS avg_delivery_days,
    AVG(CAST(dob.delivery_delay_days AS DECIMAL(10, 2))) AS avg_delay_days,
    AVG(CAST(dob.late_delivery_flag AS DECIMAL(10, 4))) AS late_delivery_rate,
    AVG(CAST(dob.avg_review_score AS DECIMAL(10, 2))) AS avg_review_score
FROM dbo.v_phase3_delivered_order_base AS dob
GROUP BY
    dob.customer_state;
GO

SELECT
    customer_region,
    delivered_order_count,
    buyer_count,
    total_payment_value,
    avg_delivery_days,
    avg_delay_days,
    late_delivery_rate,
    avg_review_score
FROM dbo.v_phase5_region_delivery_insight
ORDER BY
    late_delivery_rate DESC,
    delivered_order_count DESC;
GO

CREATE OR ALTER VIEW dbo.v_phase5_seller_category_delivery_risk
AS
WITH order_seller_category AS
(
    SELECT DISTINCT
        o.order_id,
        oi.seller_id,
        COALESCE(p.product_category_name, N'unknown') AS product_category_name,
        COALESCE(pct.product_category_name_english, p.product_category_name, N'unknown') AS product_category_name_english,
        s.seller_state,
        c.customer_state,
        DATEDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date) AS delivery_days,
        DATEDIFF(DAY, o.order_estimated_delivery_date, o.order_delivered_customer_date) AS delay_days,
        CASE
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1
            ELSE 0
        END AS late_delivery_flag
    FROM dbo.order_items AS oi
    INNER JOIN dbo.orders AS o
        ON o.order_id = oi.order_id
    INNER JOIN dbo.customers AS c
        ON c.customer_id = o.customer_id
    LEFT JOIN dbo.sellers AS s
        ON s.seller_id = oi.seller_id
    LEFT JOIN dbo.products AS p
        ON p.product_id = oi.product_id
    LEFT JOIN dbo.product_category_name_translation AS pct
        ON pct.product_category_name = p.product_category_name
    WHERE
        o.order_status = N'delivered'
        AND o.order_delivered_customer_date IS NOT NULL
        AND o.order_estimated_delivery_date IS NOT NULL
)
SELECT
    seller_id,
    seller_state,
    customer_state,
    product_category_name,
    product_category_name_english,
    COUNT_BIG(*) AS delivered_order_count,
    AVG(CAST(delivery_days AS DECIMAL(10, 2))) AS avg_delivery_days,
    AVG(CAST(delay_days AS DECIMAL(10, 2))) AS avg_delay_days,
    AVG(CAST(late_delivery_flag AS DECIMAL(10, 4))) AS late_delivery_rate
FROM order_seller_category
GROUP BY
    seller_id,
    seller_state,
    customer_state,
    product_category_name,
    product_category_name_english;
GO

SELECT TOP (100)
    seller_id,
    seller_state,
    customer_state,
    product_category_name_english,
    delivered_order_count,
    avg_delivery_days,
    avg_delay_days,
    late_delivery_rate
FROM dbo.v_phase5_seller_category_delivery_risk
WHERE
    delivered_order_count >= 20
ORDER BY
    late_delivery_rate DESC,
    avg_delay_days DESC,
    delivered_order_count DESC;
GO

CREATE OR ALTER VIEW dbo.v_phase5_cross_sell_product_pairs
AS
WITH order_product AS
(
    SELECT DISTINCT
        oi.order_id,
        oi.product_id
    FROM dbo.order_items AS oi
    INNER JOIN dbo.orders AS o
        ON o.order_id = oi.order_id
    WHERE
        o.order_status = N'delivered'
),
product_pair AS
(
    SELECT
        op1.product_id AS product_a,
        op2.product_id AS product_b,
        op1.order_id
    FROM order_product AS op1
    INNER JOIN order_product AS op2
        ON op2.order_id = op1.order_id
        AND op1.product_id < op2.product_id
)
SELECT
    pp.product_a,
    COALESCE(pa.product_category_name, N'unknown') AS product_a_category_name,
    COALESCE(pcta.product_category_name_english, pa.product_category_name, N'unknown') AS product_a_category_name_english,
    pp.product_b,
    COALESCE(pb.product_category_name, N'unknown') AS product_b_category_name,
    COALESCE(pctb.product_category_name_english, pb.product_category_name, N'unknown') AS product_b_category_name_english,
    COUNT_BIG(*) AS co_purchase_order_count
FROM product_pair AS pp
LEFT JOIN dbo.products AS pa
    ON pa.product_id = pp.product_a
LEFT JOIN dbo.product_category_name_translation AS pcta
    ON pcta.product_category_name = pa.product_category_name
LEFT JOIN dbo.products AS pb
    ON pb.product_id = pp.product_b
LEFT JOIN dbo.product_category_name_translation AS pctb
    ON pctb.product_category_name = pb.product_category_name
GROUP BY
    pp.product_a,
    COALESCE(pa.product_category_name, N'unknown'),
    COALESCE(pcta.product_category_name_english, pa.product_category_name, N'unknown'),
    pp.product_b,
    COALESCE(pb.product_category_name, N'unknown'),
    COALESCE(pctb.product_category_name_english, pb.product_category_name, N'unknown');
GO

SELECT TOP (100)
    product_a,
    product_a_category_name_english,
    product_b,
    product_b_category_name_english,
    co_purchase_order_count
FROM dbo.v_phase5_cross_sell_product_pairs
ORDER BY
    co_purchase_order_count DESC,
    product_a,
    product_b;
GO

CREATE OR ALTER VIEW dbo.v_phase5_cross_sell_category_pairs
AS
WITH order_category AS
(
    SELECT DISTINCT
        oi.order_id,
        COALESCE(pct.product_category_name_english, p.product_category_name, N'unknown') AS category_name
    FROM dbo.order_items AS oi
    INNER JOIN dbo.orders AS o
        ON o.order_id = oi.order_id
    LEFT JOIN dbo.products AS p
        ON p.product_id = oi.product_id
    LEFT JOIN dbo.product_category_name_translation AS pct
        ON pct.product_category_name = p.product_category_name
    WHERE
        o.order_status = N'delivered'
),
category_pair AS
(
    SELECT
        oc1.category_name AS category_a,
        oc2.category_name AS category_b,
        oc1.order_id
    FROM order_category AS oc1
    INNER JOIN order_category AS oc2
        ON oc2.order_id = oc1.order_id
        AND oc1.category_name < oc2.category_name
)
SELECT
    category_a,
    category_b,
    COUNT_BIG(*) AS co_purchase_order_count
FROM category_pair
GROUP BY
    category_a,
    category_b;
GO

SELECT TOP (100)
    category_a,
    category_b,
    co_purchase_order_count
FROM dbo.v_phase5_cross_sell_category_pairs
ORDER BY
    co_purchase_order_count DESC,
    category_a,
    category_b;
GO

CREATE OR ALTER VIEW dbo.v_phase5_seller_retention
AS
WITH seller_customer_order AS
(
    SELECT DISTINCT
        soa.seller_id,
        soa.customer_unique_id,
        soa.order_id,
        dob.order_purchase_timestamp
    FROM dbo.v_phase3_seller_order_analysis AS soa
    INNER JOIN dbo.v_phase3_delivered_order_base AS dob
        ON dob.order_id = soa.order_id
    WHERE
        soa.customer_unique_id IS NOT NULL
),
seller_customer_summary AS
(
    SELECT
        sco.seller_id,
        sco.customer_unique_id,
        COUNT(DISTINCT sco.order_id) AS delivered_order_count,
        MIN(sco.order_purchase_timestamp) AS first_order_time,
        MAX(sco.order_purchase_timestamp) AS last_order_time,
        DATEDIFF
        (
            DAY,
            MIN(sco.order_purchase_timestamp),
            MAX(sco.order_purchase_timestamp)
        ) AS retention_days
    FROM seller_customer_order AS sco
    GROUP BY
        sco.seller_id,
        sco.customer_unique_id
)
SELECT
    scs.seller_id,
    ss.seller_state,
    ss.seller_city,
    COUNT_BIG(*) AS total_customers,
    SUM(CASE WHEN scs.delivered_order_count > 1 THEN 1 ELSE 0 END) AS returning_customers,
    SUM(CASE WHEN scs.retention_days >= 90 THEN 1 ELSE 0 END) AS long_term_retained_customers,
    ROUND
    (
        100.0 * SUM(CASE WHEN scs.delivered_order_count > 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT_BIG(*), 0),
        2
    ) AS returning_customer_rate_percent,
    ROUND
    (
        100.0 * SUM(CASE WHEN scs.retention_days >= 90 THEN 1 ELSE 0 END)
        / NULLIF(COUNT_BIG(*), 0),
        2
    ) AS long_term_retention_rate_percent,
    AVG(CAST(scs.delivered_order_count AS DECIMAL(10, 2))) AS avg_orders_per_customer,
    AVG(CAST(scs.retention_days AS DECIMAL(10, 2))) AS avg_retention_days
FROM seller_customer_summary AS scs
LEFT JOIN dbo.v_phase3_seller_summary AS ss
    ON ss.seller_id = scs.seller_id
GROUP BY
    scs.seller_id,
    ss.seller_state,
    ss.seller_city;
GO

SELECT TOP (100)
    seller_id,
    seller_state,
    seller_city,
    total_customers,
    returning_customers,
    long_term_retained_customers,
    returning_customer_rate_percent,
    long_term_retention_rate_percent,
    avg_orders_per_customer
FROM dbo.v_phase5_seller_retention
WHERE
    total_customers >= 20
ORDER BY
    returning_customer_rate_percent DESC,
    long_term_retention_rate_percent DESC,
    total_customers DESC;
GO

CREATE OR ALTER VIEW dbo.v_phase5_monthly_forecast_simple
AS
WITH monthly AS
(
    SELECT
        mbt.order_month_start,
        YEAR(mbt.order_month_start) * 12 + MONTH(mbt.order_month_start) AS month_index,
        mbt.delivered_order_count,
        mbt.total_payment_value,
        mbt.product_gmv
    FROM dbo.v_phase5_monthly_business_trend AS mbt
),
monthly_window AS
(
    SELECT
        m.order_month_start,
        m.month_index,
        m.delivered_order_count,
        m.total_payment_value,
        m.product_gmv,
        LAG(m.total_payment_value) OVER (ORDER BY m.month_index) AS previous_month_payment_value,
        LAG(m.product_gmv) OVER (ORDER BY m.month_index) AS previous_month_product_gmv,
        AVG(m.total_payment_value) OVER
        (
            ORDER BY m.month_index
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS moving_avg_payment_3m,
        AVG(m.product_gmv) OVER
        (
            ORDER BY m.month_index
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS moving_avg_product_gmv_3m
    FROM monthly AS m
)
SELECT
    order_month_start,
    delivered_order_count,
    total_payment_value,
    previous_month_payment_value,
    total_payment_value - previous_month_payment_value AS month_over_month_payment_change,
    ROUND
    (
        100.0 * (total_payment_value - previous_month_payment_value)
        / NULLIF(previous_month_payment_value, 0),
        2
    ) AS month_over_month_payment_rate_percent,
    ROUND(moving_avg_payment_3m, 2) AS moving_avg_payment_3m,

    CASE
        WHEN previous_month_payment_value IS NULL THEN NULL
        ELSE total_payment_value + (total_payment_value - previous_month_payment_value)
    END AS simple_next_month_payment_forecast,
    product_gmv,
    previous_month_product_gmv,
    product_gmv - previous_month_product_gmv AS month_over_month_product_gmv_change,
    ROUND(moving_avg_product_gmv_3m, 2) AS moving_avg_product_gmv_3m,
    CASE
        WHEN previous_month_product_gmv IS NULL THEN NULL
        ELSE product_gmv + (product_gmv - previous_month_product_gmv)
    END AS simple_next_month_product_gmv_forecast
FROM monthly_window;
GO

SELECT
    order_month_start,
    delivered_order_count,
    total_payment_value,
    moving_avg_payment_3m,
    simple_next_month_payment_forecast,
    product_gmv,
    moving_avg_product_gmv_3m,
    simple_next_month_product_gmv_forecast
FROM dbo.v_phase5_monthly_forecast_simple
ORDER BY
    order_month_start;
GO

SELECT
    o.name AS view_name,
    o.create_date,
    o.modify_date
FROM sys.objects AS o
WHERE
    o.type = N'V'
    AND o.name LIKE N'v_phase5%'
ORDER BY
    o.name;
GO

SELECT TOP (10) * FROM dbo.v_phase5_kpi_snapshot;
GO

SELECT TOP (10) * FROM dbo.v_phase5_monthly_business_trend ORDER BY order_month_start;
GO

SELECT TOP (10) * FROM dbo.v_phase5_customer_rfm ORDER BY rfm_total_score DESC;
GO

SELECT TOP (10) * FROM dbo.v_phase5_customer_clv ORDER BY clv_12m_estimate DESC;
GO

SELECT TOP (10) * FROM dbo.v_phase5_region_delivery_insight ORDER BY late_delivery_rate DESC;
GO

SELECT TOP (10) * FROM dbo.v_phase5_cross_sell_category_pairs ORDER BY co_purchase_order_count DESC;
GO

SELECT TOP (10) * FROM dbo.v_phase5_seller_retention ORDER BY returning_customer_rate_percent DESC;
GO
