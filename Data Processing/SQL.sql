SELECT
    TO_DATE(DATE, 'DD/MM/YYYY') AS Converted_Date,
    SALES,
    COST_OF_SALES,
    QUANTITY_SOLD
FROM
    SALESANALYSIS.SALES.SALES;
-- 1. What is the daily sales price per unit?
SELECT
    DATE,
    SALES,
    COST_OF_SALES,
    QUANTITY_SOLD,
    (SALES / IFNULL(QUANTITY_SOLD, 0)) AS Daily_Price_Per_Unit
FROM
    SALESANALYSIS.SALES.SALES;
-- 2.What is the average unit sales price of this product?
SELECT
    SUM(SALES) / NULLIF(SUM(QUANTITY_SOLD), 0) AS averagesalesprice
FROM
    SALESANALYSIS.SALES.SALES;
-- 3.What is the daily % gross profit?
SELECT
    ((SALES - COST_OF_SALES) / NULLIF(SALES, 0)) * 100 AS dailygrossprofit
FROM
    SALESANALYSIS.SALES.SALES;
-- 4.What is the daily % gross profit per unit?
SELECT
    DATE,
    SALES,
    COST_OF_SALES,
    QUANTITY_SOLD,
    (SALES - COST_OF_SALES) / NULLIF(QUANTITY_SOLD, 0) AS Daily_Gross_Per_Unit
FROM
    SALESANALYSIS.SALES.SALES;
-------------------------------------------------------------------------------------------------------------
    -- 5.Pick any 3 periods during which this product was on promotion/special:
    -- o What was the Price Elasticity of Demand during each of these periods?
    --    o In your opinion, does this product perform better or worse when sold at a promotional price?
    -- Step 1: Create temp table for promo analysis
    ------------------------------------------------------------
    -- Set database and schema
    ------------------------------------------------------------
    USE DATABASE SALESANALYSIS;
USE SCHEMA SALES;
------------------------------------------------------------
    -- Create temp table for promo analysis (with Base_Start/Base_End)
    ------------------------------------------------------------
    CREATE
    OR REPLACE TEMP TABLE SALESANALYSIS.SALES.PROMO_ANALYSIS (
        Promo_Name STRING,
        Base_Start DATE,
        Base_End DATE,
        Base_Price FLOAT,
        Promo_Price FLOAT,
        Base_Qty FLOAT,
        Promo_Qty FLOAT,
        Price_Change FLOAT,
        Qty_Change FLOAT,
        Price_Elasticity FLOAT
    );
------------------------------------------------------------
    -- Insert promo data with defined base and promo periods
    ------------------------------------------------------------
INSERT INTO
    SALESANALYSIS.SALES.PROMO_ANALYSIS WITH promos AS (
        SELECT
            'Promo 1' AS Promo_Name,
            TO_DATE('30/12/2013', 'DD/MM/YYYY') AS Base_Start,
            TO_DATE('31/12/2013', 'DD/MM/YYYY') AS Base_End,
            TO_DATE('01/01/2014', 'DD/MM/YYYY') AS Promo_Start,
            TO_DATE('02/01/2014', 'DD/MM/YYYY') AS Promo_End
        UNION ALL
        SELECT
            'Promo 2',
            TO_DATE('03/01/2014', 'DD/MM/YYYY'),
            TO_DATE('04/01/2014', 'DD/MM/YYYY'),
            TO_DATE('05/01/2014', 'DD/MM/YYYY'),
            TO_DATE('06/01/2014', 'DD/MM/YYYY')
        UNION ALL
        SELECT
            'Promo 3',
            TO_DATE('06/01/2014', 'DD/MM/YYYY'),
            TO_DATE('07/01/2014', 'DD/MM/YYYY'),
            TO_DATE('08/01/2014', 'DD/MM/YYYY'),
            TO_DATE('08/01/2014', 'DD/MM/YYYY')
    )
SELECT
    p.Promo_Name,
    p.Base_Start,
    p.Base_End,
    AVG(b.SALES / NULLIF(b.QUANTITY_SOLD, 0)) AS Base_Price,
    AVG(pr.SALES / NULLIF(pr.QUANTITY_SOLD, 0)) AS Promo_Price,
    AVG(b.QUANTITY_SOLD) AS Base_Qty,
    AVG(pr.QUANTITY_SOLD) AS Promo_Qty,
    (
        (
            AVG(pr.SALES / NULLIF(pr.QUANTITY_SOLD, 0)) - AVG(b.SALES / NULLIF(b.QUANTITY_SOLD, 0))
        ) / NULLIF(AVG(b.SALES / NULLIF(b.QUANTITY_SOLD, 0)), 0)
    ) AS Price_Change,
    (
        (AVG(pr.QUANTITY_SOLD) - AVG(b.QUANTITY_SOLD)) / NULLIF(AVG(b.QUANTITY_SOLD), 0)
    ) AS Qty_Change,
    (
        (
            (AVG(pr.QUANTITY_SOLD) - AVG(b.QUANTITY_SOLD)) / NULLIF(AVG(b.QUANTITY_SOLD), 0)
        ) / NULLIF(
            (
                (
                    AVG(pr.SALES / NULLIF(pr.QUANTITY_SOLD, 0)) - AVG(b.SALES / NULLIF(b.QUANTITY_SOLD, 0))
                ) / NULLIF(AVG(b.SALES / NULLIF(b.QUANTITY_SOLD, 0)), 0)
            ),
            0
        )
    ) AS Price_Elasticity
FROM
    promos p
    LEFT JOIN SALESANALYSIS.SALES.SALES b ON TO_DATE(b.DATE, 'DD/MM/YYYY') BETWEEN p.Base_Start
    AND p.Base_End
    LEFT JOIN SALESANALYSIS.SALES.SALES pr ON TO_DATE(pr.DATE, 'DD/MM/YYYY') BETWEEN p.Promo_Start
    AND p.Promo_End
GROUP BY
    p.Promo_Name,
    p.Base_Start,
    p.Base_End
ORDER BY
    p.Promo_Name;
------------------------------------------------------------
    -- Full combined SELECT: daily metrics + rolling averages + weekdays + promo metrics
    ------------------------------------------------------------
SELECT
    TO_DATE(DATE, 'DD/MM/YYYY') AS New_Date,
    s.SALES,
    s.COST_OF_SALES,
    s.QUANTITY_SOLD,
    -- Daily metrics
    ROUND(s.SALES / NULLIF(s.QUANTITY_SOLD, 0), 2) AS Daily_Price_Per_Unit,
    ROUND(
        ((s.SALES - s.COST_OF_SALES) / NULLIF(s.SALES, 0)) * 100,
        2
    ) AS Daily_Gross_Profit_Pct,
    ROUND(
        (s.SALES - s.COST_OF_SALES) / NULLIF(s.QUANTITY_SOLD, 0),
        2
    ) AS Daily_Gross_Profit_Per_Unit,
    ROUND(
        SUM(s.SALES) OVER () / NULLIF(SUM(s.QUANTITY_SOLD) OVER (), 0),
        2
    ) AS Avg_Unit_Sales_Price,
    -- Rolling 7-day average
    ROUND(
        AVG(s.SALES) OVER(
            ORDER BY
                TO_DATE(s.DATE, 'DD/MM/YYYY') ROWS BETWEEN 6 PRECEDING
                AND CURRENT ROW
        ),
        2
    ) AS Rolling_7Day_Sales_Avg,
    -- Weekday info
    DAYNAME(TO_DATE(s.DATE, 'DD/MM/YYYY')) AS Weekday,
    ROUND(
        AVG(s.SALES) OVER(
            PARTITION BY DAYOFWEEK(TO_DATE(s.DATE, 'DD/MM/YYYY'))
        ),
        2
    ) AS Avg_Weekday_Sales,
    -- Promo info including bases
    p.Promo_Name,
    p.Base_Start,
    p.Base_End,
    p.Base_Price,
    p.Promo_Price,
    p.Base_Qty,
    p.Promo_Qty,
    ROUND(p.Price_Change * 100, 2) AS Price_Change_Pct,
    ROUND(p.Qty_Change * 100, 2) AS Qty_Change_Pct,
    ROUND(p.Price_Elasticity, 2) AS Price_Elasticity
FROM
    SALESANALYSIS.SALES.SALES s
    CROSS JOIN SALESANALYSIS.SALES.PROMO_ANALYSIS p
ORDER BY
    s.DATE,
    p.Promo_Name;
-------------------------------------------------------------------------------------------------
    ------Q5. Promo Code not Combined with Q1-Q4
    USE DATABASE SALESANALYSIS;
USE SCHEMA SALES;
CREATE
    OR REPLACE TEMP TABLE SALESANALYSIS.SALES.PROMO_ANALYSIS (
        Promo_Name STRING,
        Base_Price FLOAT,
        Promo_Price FLOAT,
        Base_Qty FLOAT,
        Promo_Qty FLOAT,
        Price_Change FLOAT,
        Qty_Change FLOAT,
        Price_Elasticity FLOAT
    );
-- 2️⃣ Insert promo data
INSERT INTO
    SALESANALYSIS.SALES.PROMO_ANALYSIS WITH promos AS (
        SELECT
            'Promo 1' AS Promo_Name,
            TO_DATE('30/12/2013', 'DD/MM/YYYY') AS Base_Start,
            TO_DATE('31/12/2013', 'DD/MM/YYYY') AS Base_End,
            TO_DATE('01/01/2014', 'DD/MM/YYYY') AS Promo_Start,
            TO_DATE('02/01/2014', 'DD/MM/YYYY') AS Promo_End
        UNION ALL
        SELECT
            'Promo 2',
            TO_DATE('03/01/2014', 'DD/MM/YYYY'),
            TO_DATE('04/01/2014', 'DD/MM/YYYY'),
            TO_DATE('05/01/2014', 'DD/MM/YYYY'),
            TO_DATE('06/01/2014', 'DD/MM/YYYY')
        UNION ALL
        SELECT
            'Promo 3',
            TO_DATE('06/01/2014', 'DD/MM/YYYY'),
            TO_DATE('07/01/2014', 'DD/MM/YYYY'),
            TO_DATE('08/01/2014', 'DD/MM/YYYY'),
            TO_DATE('08/01/2014', 'DD/MM/YYYY')
    )
SELECT
    p.Promo_Name,
    AVG(b.SALES / NULLIF(b.QUANTITY_SOLD, 0)) AS Base_Price,
    AVG(pr.SALES / NULLIF(pr.QUANTITY_SOLD, 0)) AS Promo_Price,
    AVG(b.QUANTITY_SOLD) AS Base_Qty,
    AVG(pr.QUANTITY_SOLD) AS Promo_Qty,
    (
        (
            AVG(pr.SALES / NULLIF(pr.QUANTITY_SOLD, 0)) - AVG(b.SALES / NULLIF(b.QUANTITY_SOLD, 0))
        ) / NULLIF(AVG(b.SALES / NULLIF(b.QUANTITY_SOLD, 0)), 0)
    ) AS Price_Change,
    (
        (AVG(pr.QUANTITY_SOLD) - AVG(b.QUANTITY_SOLD)) / NULLIF(AVG(b.QUANTITY_SOLD), 0)
    ) AS Qty_Change,
    (
        (
            (AVG(pr.QUANTITY_SOLD) - AVG(b.QUANTITY_SOLD)) / NULLIF(AVG(b.QUANTITY_SOLD), 0)
        ) / NULLIF(
            (
                (
                    AVG(pr.SALES / NULLIF(pr.QUANTITY_SOLD, 0)) - AVG(b.SALES / NULLIF(b.QUANTITY_SOLD, 0))
                ) / NULLIF(AVG(b.SALES / NULLIF(b.QUANTITY_SOLD, 0)), 0)
            ),
            0
        )
    ) AS Price_Elasticity
FROM
    promos p
    LEFT JOIN SALESANALYSIS.SALES.SALES b ON TO_DATE(b.DATE, 'DD/MM/YYYY') BETWEEN p.Base_Start
    AND p.Base_End
    LEFT JOIN SALESANALYSIS.SALES.SALES pr ON TO_DATE(pr.DATE, 'DD/MM/YYYY') BETWEEN p.Promo_Start
    AND p.Promo_End
GROUP BY
    p.Promo_Name
ORDER BY
    p.Promo_Name;
SELECT
    Promo_Name,
    Base_Price,
    Promo_Price,
    Base_Qty,
    Promo_Qty,
    ROUND(Price_Change * 100, 2) AS Price_Change_Pct,
    ROUND(Qty_Change * 100, 2) AS Qty_Change_Pct,
    ROUND(Price_Elasticity, 2) AS Price_Elasticity
FROM
    SALESANALYSIS.SALES.PROMO_ANALYSIS
ORDER BY
    Promo_Name;
------------------------------------------------------------------------------------------------------------
    -- Q1 - Q4 Combined
SELECT
    DATE,
    SALES,
    COST_OF_SALES,
    QUANTITY_SOLD,
    -- 1. Daily sales price per unit
    ROUND(SALES / NULLIF(QUANTITY_SOLD, 0), 2) AS Daily_Price_Per_Unit,
    -- 3. Daily % gross profit
    ROUND(
        ((SALES - COST_OF_SALES) / NULLIF(SALES, 0)) * 100,
        2
    ) AS Daily_Gross_Profit_Pct,
    -- 4. Daily % gross profit per unit
    ROUND(
        (SALES - COST_OF_SALES) / NULLIF(QUANTITY_SOLD, 0),
        2
    ) AS Daily_Gross_Profit_Per_Unit,
    -- 2. Average unit sales price (same value for all rows), it is one value. so I want to repaet for each row.
    ROUND(
        (
            SELECT
                SUM(SALES) / NULLIF(SUM(QUANTITY_SOLD), 0)
            FROM
                SALESANALYSIS.SALES.SALES
        ),
        2
    ) AS Avg_Unit_Sales_Price
FROM
    SALESANALYSIS.SALES.SALES
ORDER BY
    DATE;
------------------------------------------------------------------------------------------