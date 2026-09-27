         ----------TASK 1---------
SELECT
    o.order_id,
    o.order_date,
    
    CONCAT(c.first_name, ' ', c.last_name) AS customer_full_name,

    s.store_name,

    
    CONCAT(st.first_name, ' ', st.last_name) AS staff_full_name,

    p.product_name,
    cat.category_name,
    b.brand_name,
    oi.quantity,
    oi.list_price,
    oi.discount,
    oi.quantity * oi.list_price * (1 - oi.discount) AS net_line_revenue

FROM sales.orders AS o

JOIN sales.customers AS c
    ON o.customer_id = c.customer_id

JOIN sales.stores AS s
    ON o.store_id = s.store_id

JOIN sales.staffs AS st
    ON o.staff_id = st.staff_id

JOIN sales.order_items AS oi
    ON o.order_id = oi.order_id

JOIN production.products AS p
    ON oi.product_id = p.product_id

JOIN production.categories AS cat
    ON p.category_id = cat.category_id

JOIN production.brands AS b
    ON p.brand_id = b.brand_id;

  ------------  TASK 2  ---------------------
  SELECT
    s.store_name,
    COUNT(DISTINCT o.order_id) AS number_of_distinct_orders,
    SUM(oi.quantity) AS total_units_sold,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_net_revenue,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount))
        / COUNT(DISTINCT o.order_id) AS average_order_value
FROM sales.orders o
JOIN sales.order_items oi
    ON o.order_id = oi.order_id
JOIN sales.stores s
    ON o.store_id = s.store_id
WHERE o.order_status = 4
GROUP BY
    s.store_id,
    s.store_name
ORDER BY
    total_net_revenue DESC;

    -----------TASK  3 --------
    SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    COUNT(DISTINCT o.order_id) AS completed_order_count,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_spending
FROM sales.customers c
JOIN sales.orders o
    ON c.customer_id = o.customer_id
JOIN sales.order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 4
GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name
HAVING
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) >
    (
        SELECT AVG(customer_spending)
        FROM (
            SELECT
                o.customer_id,
                SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS customer_spending
            FROM sales.orders o
            JOIN sales.order_items oi
                ON o.order_id = oi.order_id
            WHERE o.order_status = 4
            GROUP BY o.customer_id
        ) AS customer_totals
    )
ORDER BY total_spending DESC;

              ------  TASK 4 -----
   
SELECT
    p.product_name,  
    s.store_id,
    s.quantity AS current_quantity,
    c.category_name,
    b.brand_name
FROM production.stocks s
JOIN production.products p
    ON s.product_id = p.product_id
JOIN production.categories c
    ON p.category_id = c.category_id
JOIN production.brands b
    ON p.brand_id = b.brand_id
WHERE s.quantity < 5
ORDER BY
    s.quantity ASC;
  ----------  TASK  5    ------
  WITH ProductSales AS (
    SELECT
        c.category_name,
        p.product_name,
        SUM(oi.quantity) AS total_units_sold,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_net_revenue
    FROM sales.order_items oi
    JOIN sales.orders o
        ON oi.order_id = o.order_id
    JOIN production.products p
        ON oi.product_id = p.product_id
    JOIN production.categories c
        ON p.category_id = c.category_id
    WHERE o.order_status = 'Completed'
    GROUP BY
        c.category_name,
        p.product_name
),
RankedProducts AS (
    SELECT
        category_name,
        product_name,
        total_units_sold,
        total_net_revenue,
        DENSE_RANK() OVER (
            PARTITION BY category_name
            ORDER BY total_net_revenue DESC
        ) AS product_position
    FROM ProductSales
)
SELECT
    category_name,
    product_name,
    total_units_sold,
    total_net_revenue,
    product_position
FROM RankedProducts
WHERE product_position <= 3
ORDER BY
    category_name,
    product_position,
    product_name;
    ------ TASK 6 ----------
    WITH MonthlySales AS (
    SELECT
        YEAR(o.order_date) AS year,
        MONTH(o.order_date) AS month,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_net_revenue
    FROM sales.orders o
    JOIN sales.order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY
        YEAR(o.order_date),
        MONTH(o.order_date)
),
MonthlyComparison AS (
    SELECT
        year,
        month,
        total_net_revenue,
        LAG(total_net_revenue) OVER (
            ORDER BY year, month
        ) AS previous_month_revenue
    FROM MonthlySales
)
SELECT
    year,
    month,
    total_net_revenue,
    previous_month_revenue,
    total_net_revenue - previous_month_revenue AS revenue_change
FROM MonthlyComparison
ORDER BY
    year,
    month;
    ------ TASK 7 -------
    CREATE VIEW  sales.vw_customer_sales_summary
AS
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_full_name,

    COUNT(DISTINCT CASE
        WHEN o.order_status = 'Completed'
        THEN o.order_id
    END) AS total_completed_orders,

    COALESCE(SUM(CASE
        WHEN o.order_status = 'Completed'
        THEN oi.quantity
        ELSE 0
    END), 0) AS total_units_purchased,

    COALESCE(SUM(CASE
        WHEN o.order_status = 'Completed'
        THEN oi.quantity * oi.list_price * (1 - oi.discount)
        ELSE 0
    END), 0) AS total_net_revenue,

    MAX(CASE
        WHEN o.order_status = 'Completed'
        THEN o.order_date
    END) AS most_recent_completed_order_date

FROM sales.customers c
LEFT JOIN sales.orders o
    ON c.customer_id = o.customer_id
LEFT JOIN sales.order_items oi
    ON o.order_id = oi.order_id
GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name;
    ----- TASK 8 -------
    BEGIN TRANSACTION;

-- Update customer's phone number
UPDATE sales.customers
SET phone = '(999) 555-0101'
WHERE customer_id = 1;

-- Validate the change
SELECT
    customer_id,
    first_name,
    last_name,
    phone
FROM sales.customers
WHERE customer_id = 1;

-- Testing only: undo the change
ROLLBACK TRANSACTION;
---------  TASK  9   ------
BEGIN TRANSACTION;

-- Update customer's phone number
UPDATE sales.customers
SET phone = '(999) 555-0101'
WHERE customer_id = 1;

-- Validate the change
SELECT
    customer_id,
    first_name,
    last_name,
    phone
FROM sales.customers
WHERE customer_id = 1;

-- Testing only: undo the change
ROLLBACK TRANSACTION;

----------TASK 10------------

-- Business question: Which product categories generate the most revenue in each store?
SELECT
    s.store_name,
    c.category_name,
    SUM(oi.quantity) AS total_units_sold,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_net_revenue
FROM sales.orders o
JOIN sales.order_items oi
    ON o.order_id = oi.order_id
JOIN production.products p
    ON oi.product_id = p.product_id
JOIN production.categories c
    ON p.category_id = c.category_id
JOIN sales.stores s
    ON o.store_id = s.store_id
WHERE o.order_status = 4
GROUP BY
    s.store_name,
    c.category_name
ORDER BY
    total_net_revenue DESC;