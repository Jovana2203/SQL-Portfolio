/* SCENARIO 1: RECURSIVE CTE FOR HIERARCHICAL DATA
   Objective: Build a tree structure of organizational units starting from the root.
*/

WITH org_tree AS (
    -- Identifying the root units - those without a parent sector.
    SELECT 
        unit_id, 
        unit_name, 
        parent_id, 
        0 AS level, -- Starting level is 0 (Main Sector)
        CAST(unit_name AS VARCHAR(500)) AS path -- Initializing the textual path
    FROM org_unit 
    WHERE parent_id IS NULL 

    UNION ALL 

    -- This part repeats as long as "children" exist
    SELECT 
        c.unit_id, 
        c.unit_name, 
        c.parent_id, 
        p.level + 1 AS level, -- Each subsequent sub-sector increases the level by one
        CAST(p.path + ' > ' + c.unit_name AS VARCHAR(500)) AS path -- Concatenating the parent path with the current unit name
    FROM org_unit c
    JOIN org_tree p ON c.parent_id = p.unit_id -- Joining tables via parent_id and unit_id
)
-- Extracting all data
SELECT 
    unit_id, 
    unit_name, 
    parent_id, 
    level, 
    path
FROM org_tree
ORDER BY path; -- Sorting by path provides a 'Preorder' tree traversal view


/* SCENARIO 2: GAPS AND ISLANDS (TIME-SERIES ANALYSIS)
   Objective: Find periods of consecutive purchase days for each customer.
*/

WITH UniqueSales AS (
    -- Extracting only unique PAID order dates per customer
    SELECT DISTINCT 
        customer_id, 
        CAST(order_dt AS DATE) AS sale_date -- Casting Datetime to Date to ignore time and group by days
    FROM orders
    WHERE status = 'PAID'
),
GroupedSales AS (
    -- Creating a group (grp) by subtracting the rank from the date.
    -- If dates are consecutive, this calculation will yield the same 'fictional date' for all of them.
    SELECT 
        customer_id,
        sale_date,
        DATEADD(day, -DENSE_RANK() OVER (PARTITION BY customer_id ORDER BY sale_date), sale_date) AS grp 
    FROM UniqueSales
)

-- Grouping by customer and the calculated group (grp)
SELECT 
    customer_id,
    MIN(sale_date) AS island_start, -- First day of the sequence
    MAX(sale_date) AS island_end,   -- Last day of the sequence
    DATEDIFF(day, MIN(sale_date), MAX(sale_date)) + 1 AS days_count -- Total consecutive days in the sequence
FROM GroupedSales
GROUP BY customer_id, grp
ORDER BY customer_id, island_start;


/* SCENARIO 3: RANKING WITH WINDOW FUNCTIONS
   Objective: Find the top 2 highest-paid employees for each organizational unit.
*/

WITH RankedEmployees AS (
    SELECT 
        unit_id,
        emp_id,
        full_name,
        salary, 
        -- Partitioning employees by sector and ranking them by salary from highest to lowest
        DENSE_RANK() OVER (PARTITION BY unit_id ORDER BY salary DESC) AS rank 
    FROM employee
)
SELECT 
    unit_id, 
    emp_id, 
    full_name, 
    salary,
    rank
FROM RankedEmployees
WHERE rank <= 2 -- Filtering the table to get only those in the 1st or 2nd place within their sector
ORDER BY unit_id, rank; -- Ordering for readability: first by sector, then by rank
