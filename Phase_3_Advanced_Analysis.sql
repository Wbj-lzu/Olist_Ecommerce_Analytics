/*
阶段三：高级分析
概述：运用 CTE、子查询、窗口函数与多层聚合，构建订单、月度经营、客户、卖家和物流分析视图，将明细数据整理为可复用的业务分析层。
*/

USE Olist_Ecommerce_Learning;
GO
EXEC sys.sp_helpindex N'dbo.order_payments';
GO

SELECT DB_NAME() AS current_database_name;
GO

SELECT
    o.order_status,
    COUNT_BIG(*) AS order_count
FROM dbo.orders AS o
GROUP BY o.order_status
ORDER BY order_count DESC;
GO

DROP VIEW IF EXISTS dbo.v_phase3_logistics_state_flow;
DROP VIEW IF EXISTS dbo.v_phase3_customer_summary;
DROP VIEW IF EXISTS dbo.v_phase3_seller_summary;
DROP VIEW IF EXISTS dbo.v_phase3_monthly_business;
DROP VIEW IF EXISTS dbo.v_phase3_seller_order_analysis;
DROP VIEW IF EXISTS dbo.v_phase3_order_seller_base;
DROP VIEW IF EXISTS dbo.v_phase3_delivered_order_base;
DROP VIEW IF EXISTS dbo.v_phase3_order_review_score;
DROP VIEW IF EXISTS dbo.v_phase3_order_item_summary;
DROP VIEW IF EXISTS dbo.v_phase3_order_payment;
GO

CREATE OR ALTER VIEW dbo.v_phase3_order_payment
AS
SELECT
    op.order_id,

    COUNT_BIG(*) AS payment_record_count,

    COUNT(DISTINCT op.payment_type) AS payment_type_count,

    MAX(ISNULL(op.payment_installments, 0)) AS max_payment_installments,

    SUM(ISNULL(op.payment_value, 0)) AS total_payment_value
FROM dbo.order_payments AS op
GROUP BY
    op.order_id;
GO

SELECT TOP 10 *
FROM dbo.v_phase3_order_payment;
GO

CREATE OR ALTER VIEW dbo.v_phase3_order_item_summary
AS
SELECT
    oi.order_id,

    COUNT_BIG(*) AS item_row_count,

    COUNT(DISTINCT oi.product_id) AS product_count,

    COUNT(DISTINCT oi.seller_id) AS seller_count,

    SUM(ISNULL(oi.price, 0)) AS product_gmv,

    SUM(ISNULL(oi.freight_value, 0)) AS freight_value,

    SUM(ISNULL(oi.price, 0) + ISNULL(oi.freight_value, 0)) AS item_total_value
FROM dbo.order_items AS oi
GROUP BY
    oi.order_id;
GO

SELECT TOP 10 *
FROM dbo.v_phase3_order_item_summary;
GO

CREATE OR ALTER VIEW dbo.v_phase3_order_review_score
AS
SELECT
    r.order_id,

    AVG(CAST(r.review_score AS DECIMAL(10, 2))) AS avg_review_score,

    COUNT_BIG(*) AS review_row_count,

    COUNT(DISTINCT r.review_id) AS review_id_count,

    MAX(r.review_creation_date) AS latest_review_creation_date,
    MAX(r.review_answer_timestamp) AS latest_review_answer_timestamp
FROM dbo.order_reviews AS r
GROUP BY
    r.order_id;
GO

CREATE OR ALTER VIEW dbo.v_phase3_delivered_order_base
AS
SELECT
    o.order_id,
    o.customer_id,

    c.customer_unique_id,
    c.customer_city,
    c.customer_state,

    o.order_status,
    o.order_purchase_timestamp,

    YEAR(o.order_purchase_timestamp) AS order_year,
    MONTH(o.order_purchase_timestamp) AS order_month,

    CASE
        WHEN o.order_purchase_timestamp IS NOT NULL

            THEN DATEFROMPARTS(
                YEAR(o.order_purchase_timestamp),
                MONTH(o.order_purchase_timestamp),
                1
            )
    END AS order_month_start,

    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    ISNULL(op.payment_record_count, 0) AS payment_record_count,
    ISNULL(op.payment_type_count, 0) AS payment_type_count,
    ISNULL(op.max_payment_installments, 0) AS max_payment_installments,
    ISNULL(op.total_payment_value, 0) AS total_payment_value,

    ISNULL(oi.item_row_count, 0) AS item_row_count,
    ISNULL(oi.product_count, 0) AS product_count,
    ISNULL(oi.seller_count, 0) AS seller_count,
    ISNULL(oi.product_gmv, 0) AS product_gmv,
    ISNULL(oi.freight_value, 0) AS freight_value,
    ISNULL(oi.item_total_value, 0) AS item_total_value,

    ors.avg_review_score,
    ors.review_row_count,

    DATEDIFF(
        DAY,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date
    ) AS purchase_to_delivery_days,

    DATEDIFF(
        DAY,
        o.order_purchase_timestamp,
        o.order_approved_at
    ) AS purchase_to_approval_days,

    DATEDIFF(
        DAY,
        o.order_approved_at,
        o.order_delivered_carrier_date
    ) AS approval_to_carrier_days,

    DATEDIFF(
        DAY,
        o.order_delivered_carrier_date,
        o.order_delivered_customer_date
    ) AS carrier_to_customer_days,

    DATEDIFF(
        DAY,
        o.order_estimated_delivery_date,
        o.order_delivered_customer_date
    ) AS delivery_delay_days,

    CASE
        WHEN o.order_delivered_customer_date IS NOT NULL
         AND o.order_estimated_delivery_date IS NOT NULL
         AND CAST(o.order_delivered_customer_date AS DATE)
             > CAST(o.order_estimated_delivery_date AS DATE)
            THEN 1
        ELSE 0
    END AS late_delivery_flag
FROM dbo.orders AS o

INNER JOIN dbo.customers AS c
    ON o.customer_id = c.customer_id

LEFT JOIN dbo.v_phase3_order_payment AS op
    ON o.order_id = op.order_id
LEFT JOIN dbo.v_phase3_order_item_summary AS oi
    ON o.order_id = oi.order_id
LEFT JOIN dbo.v_phase3_order_review_score AS ors
    ON o.order_id = ors.order_id

WHERE o.order_status = 'delivered';
GO

CREATE OR ALTER VIEW dbo.v_phase3_order_seller_base
AS
SELECT
    oi.order_id,
    oi.seller_id,
    s.seller_city,
    s.seller_state,

    COUNT_BIG(*) AS seller_item_row_count,

    COUNT(DISTINCT oi.product_id) AS seller_product_count,

    SUM(ISNULL(oi.price, 0)) AS seller_product_gmv,

    SUM(ISNULL(oi.freight_value, 0)) AS seller_freight_value,

    MIN(oi.shipping_limit_date) AS first_shipping_limit_date,
    MAX(oi.shipping_limit_date) AS last_shipping_limit_date
FROM dbo.order_items AS oi
LEFT JOIN dbo.sellers AS s
    ON oi.seller_id = s.seller_id
GROUP BY
    oi.order_id,
    oi.seller_id,
    s.seller_city,
    s.seller_state;
GO

CREATE OR ALTER VIEW dbo.v_phase3_seller_order_analysis
AS
SELECT
    os.order_id,
    os.seller_id,
    os.seller_city,
    os.seller_state,

    dob.customer_unique_id,
    dob.customer_city,
    dob.customer_state,
    dob.order_purchase_timestamp,
    dob.order_year,
    dob.order_month,
    dob.order_month_start,

    os.seller_item_row_count,
    os.seller_product_count,
    os.seller_product_gmv,
    os.seller_freight_value,

    dob.total_payment_value AS order_total_payment_value,
    dob.product_gmv AS order_product_gmv,
    dob.freight_value AS order_freight_value,

    dob.avg_review_score,
    dob.purchase_to_delivery_days,
    dob.delivery_delay_days,
    dob.late_delivery_flag
FROM dbo.v_phase3_order_seller_base AS os
INNER JOIN dbo.v_phase3_delivered_order_base AS dob
    ON os.order_id = dob.order_id;
GO

CREATE OR ALTER VIEW dbo.v_phase3_monthly_business
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

    AVG(
        CAST(dob.total_payment_value AS DECIMAL(18, 2))
    ) AS avg_payment_per_order,

    AVG(
        CAST(dob.purchase_to_delivery_days AS DECIMAL(10, 2))
    ) AS avg_delivery_days,

    AVG(
        CAST(dob.late_delivery_flag AS DECIMAL(10, 4))
    ) AS late_delivery_rate,

    AVG(
        CAST(dob.avg_review_score AS DECIMAL(10, 2))
    ) AS avg_review_score
FROM dbo.v_phase3_delivered_order_base AS dob
GROUP BY
    dob.order_year,
    dob.order_month,
    dob.order_month_start;
GO

CREATE OR ALTER VIEW dbo.v_phase3_customer_summary
AS
SELECT
    dob.customer_unique_id,

    COUNT(DISTINCT dob.order_id) AS delivered_order_count,

    SUM(dob.total_payment_value) AS total_payment_value,

    SUM(dob.product_gmv) AS product_gmv,
    SUM(dob.freight_value) AS freight_value,

    AVG(
        CAST(dob.total_payment_value AS DECIMAL(18, 2))
    ) AS avg_payment_per_order,

    MIN(dob.order_purchase_timestamp) AS first_purchase_time,
    MAX(dob.order_purchase_timestamp) AS last_purchase_time,

    DATEDIFF(
        DAY,
        MIN(dob.order_purchase_timestamp),
        MAX(dob.order_purchase_timestamp)
    ) AS customer_lifetime_days,

    AVG(
        CAST(dob.avg_review_score AS DECIMAL(10, 2))
    ) AS avg_review_score,

    AVG(
        CAST(dob.late_delivery_flag AS DECIMAL(10, 4))
    ) AS late_delivery_rate
FROM dbo.v_phase3_delivered_order_base AS dob
WHERE dob.customer_unique_id IS NOT NULL
GROUP BY
    dob.customer_unique_id;
GO

CREATE OR ALTER VIEW dbo.v_phase3_seller_summary
AS
SELECT
    soa.seller_id,
    soa.seller_city,
    soa.seller_state,

    COUNT(DISTINCT soa.order_id) AS delivered_order_count,

    COUNT(DISTINCT soa.customer_unique_id) AS buyer_count,

    SUM(soa.seller_item_row_count) AS seller_item_row_count,

    SUM(soa.seller_product_gmv) AS seller_product_gmv,

    SUM(soa.seller_freight_value) AS seller_freight_value,

    AVG(
        CAST(soa.avg_review_score AS DECIMAL(10, 2))
    ) AS avg_review_score,

    COUNT(soa.avg_review_score) AS reviewed_order_count,

    AVG(
        CAST(soa.purchase_to_delivery_days AS DECIMAL(10, 2))
    ) AS avg_delivery_days,

    AVG(
        CAST(soa.late_delivery_flag AS DECIMAL(10, 4))
    ) AS late_delivery_rate
FROM dbo.v_phase3_seller_order_analysis AS soa
GROUP BY
    soa.seller_id,
    soa.seller_city,
    soa.seller_state;
GO

CREATE OR ALTER VIEW dbo.v_phase3_logistics_state_flow
AS
SELECT
    soa.seller_state,
    soa.customer_state,

    COUNT(DISTINCT soa.order_id) AS delivered_order_count,

    COUNT(DISTINCT soa.seller_id) AS seller_count,

    COUNT(DISTINCT soa.customer_unique_id) AS buyer_count,

    SUM(soa.seller_product_gmv) AS seller_product_gmv,

    AVG(
        CAST(soa.purchase_to_delivery_days AS DECIMAL(10, 2))
    ) AS avg_delivery_days,

    AVG(
        CAST(soa.delivery_delay_days AS DECIMAL(10, 2))
    ) AS avg_delay_days,

    AVG(
        CAST(soa.late_delivery_flag AS DECIMAL(10, 4))
    ) AS late_delivery_rate
FROM dbo.v_phase3_seller_order_analysis AS soa

WHERE soa.seller_state IS NOT NULL
  AND soa.customer_state IS NOT NULL

GROUP BY
    soa.seller_state,
    soa.customer_state;
GO

SELECT TOP (20)
    dob.order_id,
    dob.customer_unique_id,
    dob.order_purchase_timestamp,
    dob.total_payment_value,
    dob.product_gmv,
    dob.freight_value,
    dob.item_row_count,
    dob.seller_count,
    dob.avg_review_score,
    dob.purchase_to_delivery_days,
    dob.late_delivery_flag
FROM dbo.v_phase3_delivered_order_base AS dob

ORDER BY
    dob.order_purchase_timestamp,
    dob.order_id;
GO

SELECT
    COUNT_BIG(*) AS duplicate_order_id_count
FROM
(

    SELECT
        dob.order_id
    FROM dbo.v_phase3_delivered_order_base AS dob
    GROUP BY
        dob.order_id
    HAVING COUNT_BIG(*) > 1
) AS duplicated_orders;
GO

WITH correct_amount AS
(

    SELECT
        SUM(dob.total_payment_value) AS correct_total_payment
    FROM dbo.v_phase3_delivered_order_base AS dob
),
wrong_amount AS
(

    SELECT
        SUM(ISNULL(op.payment_value, 0))
            AS wrong_total_payment_after_join
    FROM dbo.orders AS o
    INNER JOIN dbo.order_payments AS op
        ON o.order_id = op.order_id
    INNER JOIN dbo.order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
)

SELECT
    c.correct_total_payment,
    w.wrong_total_payment_after_join,

    w.wrong_total_payment_after_join
        - c.correct_total_payment AS overcount_amount,

    CAST(
        w.wrong_total_payment_after_join
        / NULLIF(c.correct_total_payment, 0)
        AS DECIMAL(18, 4)
    ) AS wrong_to_correct_ratio
FROM correct_amount AS c
CROSS JOIN wrong_amount AS w;
GO

SELECT

    SUM(dob.total_payment_value) AS total_payment_value,

    SUM(dob.product_gmv) AS product_gmv,

    SUM(dob.freight_value) AS freight_value,

    SUM(dob.item_total_value) AS item_total_value,

    SUM(dob.total_payment_value)
        - SUM(dob.item_total_value) AS payment_minus_item_total
FROM dbo.v_phase3_delivered_order_base AS dob;
GO

SELECT
    mb.order_year,
    mb.order_month,
    mb.order_month_start,

    mb.delivered_order_count,

    mb.buyer_count,

    mb.total_payment_value,

    mb.product_gmv,

    mb.freight_value,

    mb.avg_payment_per_order,

    mb.avg_delivery_days,

    mb.late_delivery_rate,

    mb.avg_review_score
FROM dbo.v_phase3_monthly_business AS mb

ORDER BY
    mb.order_month_start;
GO

SELECT

    mb.order_month_start,

    mb.delivered_order_count,

    mb.total_payment_value,

    mb.product_gmv,

    SUM(mb.total_payment_value) OVER
    (
        ORDER BY mb.order_month_start
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_payment_value,

    SUM(mb.product_gmv) OVER
    (
        ORDER BY mb.order_month_start
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_product_gmv

FROM dbo.v_phase3_monthly_business AS mb

ORDER BY
    mb.order_month_start;
GO

SELECT TOP (200)

    dob.customer_unique_id,

    dob.order_id,

    dob.order_purchase_timestamp,

    dob.total_payment_value,

    SUM(dob.total_payment_value) OVER
    (
        PARTITION BY dob.customer_unique_id

        ORDER BY
            dob.order_purchase_timestamp,
            dob.order_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_customer_payment_value

FROM dbo.v_phase3_delivered_order_base AS dob

WHERE dob.customer_unique_id IS NOT NULL

ORDER BY
    dob.customer_unique_id,
    dob.order_purchase_timestamp,
    dob.order_id;
GO

SELECT

    dob.order_id,

    dob.customer_unique_id,

    dob.order_purchase_timestamp,

    dob.item_row_count,

    dob.product_count,

    dob.total_payment_value

FROM dbo.v_phase3_delivered_order_base AS dob

WHERE dob.item_row_count >
(

    SELECT
        AVG(
            CAST(x.item_row_count AS DECIMAL(10, 2))
        )
    FROM dbo.v_phase3_delivered_order_base AS x
)

ORDER BY
    dob.item_row_count DESC,
    dob.total_payment_value DESC;
GO

WITH order_category_base AS
(

    SELECT
        oi.order_id,

        COALESCE(
            pct.product_category_name_english,
            p.product_category_name,
            N'未分类'
        ) AS product_category,

        COUNT_BIG(*) AS item_row_count,

        SUM(ISNULL(oi.price, 0)) AS category_product_gmv,

        SUM(ISNULL(oi.freight_value, 0)) AS category_freight_value

    FROM dbo.order_items AS oi

    INNER JOIN dbo.v_phase3_delivered_order_base AS dob
        ON oi.order_id = dob.order_id

    LEFT JOIN dbo.products AS p
        ON oi.product_id = p.product_id

    LEFT JOIN dbo.product_category_name_translation AS pct
        ON p.product_category_name = pct.product_category_name

    GROUP BY
        oi.order_id,
        COALESCE(
            pct.product_category_name_english,
            p.product_category_name,
            N'未分类'
        )
),
category_summary AS
(

    SELECT
        ocb.product_category,

        COUNT_BIG(*) AS order_category_count,

        SUM(ocb.item_row_count) AS item_row_count,

        SUM(ocb.category_product_gmv) AS product_gmv,

        SUM(ocb.category_freight_value) AS freight_value,

        AVG(
            CAST(dob.avg_review_score AS DECIMAL(10, 2))
        ) AS avg_review_score,

        AVG(
            CAST(dob.late_delivery_flag AS DECIMAL(10, 4))
        ) AS late_delivery_rate

    FROM order_category_base AS ocb
    INNER JOIN dbo.v_phase3_delivered_order_base AS dob
        ON ocb.order_id = dob.order_id

    GROUP BY
        ocb.product_category
)

SELECT
    cs.product_category,
    cs.order_category_count,
    cs.item_row_count,
    cs.product_gmv,
    cs.freight_value,
    cs.avg_review_score,
    cs.late_delivery_rate
FROM category_summary AS cs

ORDER BY
    cs.product_gmv DESC;
GO

WITH product_summary AS
(
    SELECT
        oi.product_id,
        COALESCE(
            pct.product_category_name_english,
            p.product_category_name,
            N'未分类'
        ) AS product_category,
        COUNT(DISTINCT oi.order_id) AS delivered_order_count,
        COUNT_BIG(*) AS item_row_count,
        SUM(ISNULL(oi.price, 0)) AS product_gmv,
        SUM(ISNULL(oi.freight_value, 0)) AS freight_value
    FROM dbo.order_items AS oi

    INNER JOIN dbo.orders AS o
        ON oi.order_id = o.order_id
       AND o.order_status = 'delivered'

    LEFT JOIN dbo.products AS p
        ON oi.product_id = p.product_id
    LEFT JOIN dbo.product_category_name_translation AS pct
        ON p.product_category_name = pct.product_category_name
    GROUP BY
        oi.product_id,
        COALESCE(
            pct.product_category_name_english,
            p.product_category_name,
            N'未分类'
        )
),
product_with_average AS
(
    SELECT
        ps.product_id,
        ps.product_category,
        ps.delivered_order_count,
        ps.item_row_count,
        ps.product_gmv,
        ps.freight_value,
        AVG(CAST(ps.product_gmv AS DECIMAL(18, 2))) OVER () AS avg_product_gmv
    FROM product_summary AS ps
)
SELECT TOP (50)
    ps.product_id,
    ps.product_category,
    ps.delivered_order_count,
    ps.item_row_count,
    ps.product_gmv,
    ps.freight_value,
    ps.avg_product_gmv
FROM product_with_average AS ps
WHERE ps.product_gmv > ps.avg_product_gmv
ORDER BY
    ps.product_gmv DESC;
GO

SELECT TOP (100)
    cs.customer_unique_id,
    cs.delivered_order_count,
    cs.total_payment_value,
    cs.product_gmv,
    cs.freight_value,
    cs.avg_payment_per_order,
    cs.first_purchase_time,
    cs.last_purchase_time,
    cs.customer_lifetime_days,
    cs.avg_review_score,
    cs.late_delivery_rate
FROM dbo.v_phase3_customer_summary AS cs
ORDER BY
    cs.total_payment_value DESC;
GO

WITH customer_segmented AS
(
    SELECT
        cs.*,

        CASE
            WHEN cs.delivered_order_count = 1
                THEN N'一次购买客户'
            WHEN cs.delivered_order_count BETWEEN 2 AND 3
                THEN N'轻度复购客户'
            WHEN cs.delivered_order_count BETWEEN 4 AND 6
                THEN N'中度复购客户'
            ELSE N'高复购客户'
        END AS customer_segment
    FROM dbo.v_phase3_customer_summary AS cs
)
SELECT
    cseg.customer_segment,
    COUNT_BIG(*) AS customer_count,
    SUM(cseg.total_payment_value) AS total_payment_value,
    AVG(CAST(cseg.total_payment_value AS DECIMAL(18, 2))) AS avg_customer_value,
    AVG(CAST(cseg.avg_payment_per_order AS DECIMAL(18, 2))) AS avg_order_payment,
    AVG(CAST(cseg.avg_review_score AS DECIMAL(10, 2))) AS avg_review_score,
    AVG(CAST(cseg.late_delivery_rate AS DECIMAL(10, 4))) AS late_delivery_rate
FROM customer_segmented AS cseg
GROUP BY
    cseg.customer_segment
ORDER BY
    total_payment_value DESC;
GO

SELECT TOP (100)
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
    ss.late_delivery_rate
FROM dbo.v_phase3_seller_summary AS ss
ORDER BY
    ss.seller_product_gmv DESC;
GO

SELECT TOP (200)
    ss.seller_id,
    ss.seller_state,
    ss.delivered_order_count,
    ss.seller_product_gmv,
    ss.avg_review_score,
    ss.late_delivery_rate,

    RANK() OVER
    (
        PARTITION BY ss.seller_state
        ORDER BY ss.seller_product_gmv DESC
    ) AS rank_in_seller_state_by_gmv,

    RANK() OVER
    (
        ORDER BY ss.seller_product_gmv DESC
    ) AS overall_rank_by_gmv
FROM dbo.v_phase3_seller_summary AS ss
ORDER BY
    overall_rank_by_gmv,
    ss.seller_id;
GO

WITH seller_scored AS

(
    SELECT
        ss.*,

        NTILE(4) OVER
        (
            ORDER BY ss.seller_product_gmv
        ) AS revenue_quartile,

        NTILE(4) OVER
        (
            ORDER BY ss.delivered_order_count
        ) AS order_quartile,

        NTILE(4) OVER
        (
            ORDER BY ISNULL(ss.avg_review_score, 0)
        ) AS review_quartile,

        NTILE(4) OVER
        (
            ORDER BY ISNULL(ss.late_delivery_rate, 0)
        ) AS late_risk_quartile
    FROM dbo.v_phase3_seller_summary AS ss
),
seller_segmented AS
(
    SELECT
        ssc.*,
        CASE
            WHEN ssc.delivered_order_count < 5
                THEN N'样本不足卖家'
            WHEN ssc.revenue_quartile = 4
             AND ssc.review_quartile >= 3
             AND ssc.late_risk_quartile <= 2
                THEN N'核心优质卖家'
            WHEN ssc.revenue_quartile = 4
             AND (
                    ssc.review_quartile <= 2
                 OR ssc.late_risk_quartile >= 3
                 )
                THEN N'高收入高风险卖家'
            WHEN ssc.revenue_quartile <= 2
             AND ssc.review_quartile = 4
             AND ssc.late_risk_quartile <= 2
                THEN N'口碑潜力卖家'
            WHEN ssc.late_risk_quartile = 4
                THEN N'物流重点优化卖家'
            ELSE N'稳定普通卖家'
        END AS seller_segment
    FROM seller_scored AS ssc
)
SELECT TOP (200)
    sseg.seller_id,
    sseg.seller_state,
    sseg.seller_segment,
    sseg.delivered_order_count,
    sseg.seller_product_gmv,
    sseg.avg_review_score,
    sseg.reviewed_order_count,
    sseg.avg_delivery_days,
    sseg.late_delivery_rate,
    sseg.revenue_quartile,
    sseg.review_quartile,
    sseg.late_risk_quartile
FROM seller_segmented AS sseg
ORDER BY
    sseg.seller_product_gmv DESC,
    sseg.seller_id;
GO

WITH seller_scored AS
(
    SELECT
        ss.*,
        NTILE(4) OVER (ORDER BY ss.seller_product_gmv) AS revenue_quartile,
        NTILE(4) OVER (ORDER BY ISNULL(ss.avg_review_score, 0)) AS review_quartile,
        NTILE(4) OVER (ORDER BY ISNULL(ss.late_delivery_rate, 0)) AS late_risk_quartile
    FROM dbo.v_phase3_seller_summary AS ss
),
seller_segmented AS
(
    SELECT
        ssc.*,
        CASE
            WHEN ssc.delivered_order_count < 5 THEN N'样本不足卖家'
            WHEN ssc.revenue_quartile = 4
             AND ssc.review_quartile >= 3
             AND ssc.late_risk_quartile <= 2 THEN N'核心优质卖家'
            WHEN ssc.revenue_quartile = 4
             AND (ssc.review_quartile <= 2 OR ssc.late_risk_quartile >= 3) THEN N'高收入高风险卖家'
            WHEN ssc.revenue_quartile <= 2
             AND ssc.review_quartile = 4
             AND ssc.late_risk_quartile <= 2 THEN N'口碑潜力卖家'
            WHEN ssc.late_risk_quartile = 4 THEN N'物流重点优化卖家'
            ELSE N'稳定普通卖家'
        END AS seller_segment
    FROM seller_scored AS ssc
)
SELECT
    sseg.seller_segment,
    COUNT_BIG(*) AS seller_count,
    SUM(sseg.delivered_order_count) AS delivered_order_count,
    SUM(sseg.seller_product_gmv) AS seller_product_gmv,
    AVG(CAST(sseg.avg_review_score AS DECIMAL(10, 2))) AS avg_review_score,
    AVG(CAST(sseg.avg_delivery_days AS DECIMAL(10, 2))) AS avg_delivery_days,
    AVG(CAST(sseg.late_delivery_rate AS DECIMAL(10, 4))) AS late_delivery_rate
FROM seller_segmented AS sseg
GROUP BY
    sseg.seller_segment
ORDER BY
    seller_product_gmv DESC;
GO

SELECT TOP (50)
    lsf.seller_state,
    lsf.customer_state,
    lsf.delivered_order_count,
    lsf.seller_count,
    lsf.buyer_count,
    lsf.seller_product_gmv,
    lsf.avg_delivery_days,
    lsf.avg_delay_days,
    lsf.late_delivery_rate
FROM dbo.v_phase3_logistics_state_flow AS lsf
ORDER BY
    lsf.delivered_order_count DESC,
    lsf.seller_product_gmv DESC;
GO

SELECT TOP (50)
    lsf.seller_state,
    lsf.customer_state,
    lsf.delivered_order_count,
    lsf.seller_product_gmv,
    lsf.avg_delivery_days,
    lsf.avg_delay_days,
    lsf.late_delivery_rate
FROM dbo.v_phase3_logistics_state_flow AS lsf
WHERE lsf.delivered_order_count >= 100
ORDER BY
    lsf.late_delivery_rate DESC,
    lsf.avg_delay_days DESC,
    lsf.delivered_order_count DESC;
GO

WITH order_seller_zip AS
(
    SELECT
        soa.order_id,
        soa.seller_id,
        soa.seller_state,
        soa.customer_state,
        soa.purchase_to_delivery_days,
        soa.delivery_delay_days,
        soa.late_delivery_flag,

        customer_geo.avg_geolocation_lat AS customer_lat,
        customer_geo.avg_geolocation_lng AS customer_lng,
        seller_geo.avg_geolocation_lat AS seller_lat,
        seller_geo.avg_geolocation_lng AS seller_lng
    FROM dbo.v_phase3_seller_order_analysis AS soa
    INNER JOIN dbo.orders AS o
        ON soa.order_id = o.order_id
    INNER JOIN dbo.customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN dbo.sellers AS s
        ON soa.seller_id = s.seller_id
    LEFT JOIN dbo.v_geolocation_zip_prefix AS customer_geo
        ON c.customer_zip_code_prefix = customer_geo.geolocation_zip_code_prefix
    LEFT JOIN dbo.v_geolocation_zip_prefix AS seller_geo
        ON s.seller_zip_code_prefix = seller_geo.geolocation_zip_code_prefix
),
coordinate_ready AS
(
    SELECT
        osz.*,

        COS(RADIANS(osz.seller_lat))
        * COS(RADIANS(osz.customer_lat))
        * COS(RADIANS(osz.customer_lng) - RADIANS(osz.seller_lng))
        + SIN(RADIANS(osz.seller_lat))
        * SIN(RADIANS(osz.customer_lat)) AS acos_input
    FROM order_seller_zip AS osz
    WHERE osz.customer_lat IS NOT NULL
      AND osz.customer_lng IS NOT NULL
      AND osz.seller_lat IS NOT NULL
      AND osz.seller_lng IS NOT NULL
),
distance_base AS
(
    SELECT
        cr.*,
        6371.0 * ACOS(
            CASE
                WHEN cr.acos_input > 1 THEN 1
                WHEN cr.acos_input < -1 THEN -1
                ELSE cr.acos_input
            END
        ) AS estimated_distance_km
    FROM coordinate_ready AS cr
),
distance_with_band AS
(
    SELECT
        db.*,
        CASE
            WHEN db.estimated_distance_km < 100 THEN N'0-99 km'
            WHEN db.estimated_distance_km < 500 THEN N'100-499 km'
            WHEN db.estimated_distance_km < 1000 THEN N'500-999 km'
            WHEN db.estimated_distance_km < 2000 THEN N'1000-1999 km'
            ELSE N'2000 km 及以上'
        END AS distance_band
    FROM distance_base AS db
)
SELECT
    dwb.distance_band,
    COUNT_BIG(*) AS seller_order_count,
    AVG(CAST(dwb.estimated_distance_km AS DECIMAL(18, 2))) AS avg_estimated_distance_km,
    AVG(CAST(dwb.purchase_to_delivery_days AS DECIMAL(10, 2))) AS avg_delivery_days,
    AVG(CAST(dwb.delivery_delay_days AS DECIMAL(10, 2))) AS avg_delay_days,
    AVG(CAST(dwb.late_delivery_flag AS DECIMAL(10, 4))) AS late_delivery_rate
FROM distance_with_band AS dwb
GROUP BY
    dwb.distance_band
ORDER BY
    MIN(dwb.estimated_distance_km);
GO
