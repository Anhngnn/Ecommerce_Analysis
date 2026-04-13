USE ECommercial_Project
GO

SELECT * FROM orders
SELECT * FROM order_items
SELECT * FROM order_item_refunds
SELECT * FROM products
SELECT * FROM website_pageviews
SELECT * FROM website_sessions


---GROWTH:
WITH CTE_Sessions as 
(
SELECT 
	DATETRUNC(MONTH,created_at) AS month,
	COUNT(DISTINCT website_session_id) AS Total_sessions
FROM website_sessions
GROUP BY DATETRUNC(MONTH,created_at)
),
CTE_Orders as
(
SELECT 
	DATETRUNC(MONTH,created_at) AS Month,
	COUNT(DISTINCT order_id) AS Total_orders
FROM orders
GROUP BY DATETRUNC(MONTH,created_at)
)
SELECT 
	s.month,
	s.Total_sessions,
	o.Total_orders,
	ROUND(o.Total_orders*1.0/s.Total_sessions,4)*100 AS conversion_rate
FROM CTE_Sessions  s LEFT JOIN CTE_Orders o ON s.month = o.month
ORDER BY s.month

SELECT DISTINCT pageview_url FROM website_pageviews

--FUNNEL:
WITH CTE_SessionLevel AS
(
	SELECT
		website_session_id,
		MAX (CASE WHEN pageview_url IN ('/the-forever-love-bear','/the-birthday-sugar-panda','/the-original-mr-fuzzy','/the-hudson-river-mini-bear') THEN 1 ELSE 0 END ) AS view_product,
		MAX(CASE WHEN pageview_url ='/cart' THEN 1 ELSE 0 END) AS view_cart,
		MAX(CASE WHEN pageview_url IN ('/billing','/billing-2') THEN 1 ELSE 0 END) as view_billing,
		MAX(CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END) AS made_orders
	FROM website_pageviews
	GROUP BY website_session_id
)
SELECT 
	COUNT(*) as Session,
	SUM(view_product) AS Total_view_product,
	SUM(view_cart) AS Total_view_cart,
	SUM(view_billing) AS Total_view_billing,
	SUM(made_orders) AS Total_orders,
	ROUND(SUM(view_product)*1.0/COUNT(*),4)*100 AS session_to_product,
	ROUND(SUM(view_cart)*1.0/SUM(view_product),4)*100 AS product_to_cart,
	ROUND(SUM(view_billing)*1.0/SUM(view_cart),4)*100 AS cart_to_billing,
	ROUND(SUM(made_orders)*1.0/SUM(view_billing),4)*100 AS billing_to_orders
FROM CTE_SessionLevel

--LADING PAGE ANALYSIS: lading page nào khiến user không vào product
WITH Lading_page as
(
	SELECT 
	website_session_id,
	MIN(website_pageview_id) AS first_pageview
	FROM website_pageviews
	GROUP BY website_session_id
),
Lading_page_url as
(
	SELECT
	lp.website_session_id,
	wp.pageview_url AS lading_page
	FROM Lading_page lp 
	JOIN  website_pageviews wp ON lp.first_pageview = wp.website_pageview_id
),
product AS
(
	SELECT 
	website_session_id,
	MAX (CASE WHEN pageview_url IN ('/the-forever-love-bear',
									'/the-birthday-sugar-panda',
									'/the-original-mr-fuzzy',
									'/the-hudson-river-mini-bear') THEN 1 ELSE 0 END ) AS view_product
	FROM website_pageviews
	GROUP BY website_session_id
)
SELECT
	lading_page,
	COUNT(*) as Session,
	SUM(p.view_product) AS total_view_product,
	ROUND(SUM(p.view_product)*1.0/COUNT(*),4)*100 AS lading_to_product
FROM lading_page_url ldu
JOIN product p ON ldu.website_session_id = p.website_session_id
GROUP BY lading_page
ORDER BY lading_to_product

---CHANNEL ANALSIS:
---Channel performance
WITH session_orders AS
(
	SELECT 
		ws.website_session_id,
		ws.utm_source,
		ws.utm_campaign,
		(CASE WHEN o.order_id is not null then 1 else 0 end) as made_order
	FROM website_sessions ws
	LEFT JOIN orders o ON o.website_session_id = ws.website_session_id
)
SELECT 
	utm_source,
	utm_campaign,
	COUNT(website_session_id) AS Session,
	SUM(made_order) as Total_orders,
	ROUND(SUM(made_order)*1.0/COUNT(website_session_id),4)*100 AS CR
FROM session_orders
GROUP BY utm_source, utm_campaign
ORDER BY session desc,total_orders,CR

---Channel&Lading Page: Kênh nào đang đưa traffic vào landing tệ?
WITH Lading_page as
(
	SELECT 
	website_session_id,
	MIN(website_pageview_id) AS first_pageview
	FROM website_pageviews
	GROUP BY website_session_id
),
Lading_page_url as
(
	SELECT
	lp.website_session_id,
	wp.pageview_url AS lading_page
	FROM Lading_page lp 
	JOIN  website_pageviews wp ON lp.first_pageview = wp.website_pageview_id
),
session_data AS
(
	SELECT 
		ws.website_session_id,
		ws.utm_source,
		ws.utm_campaign,
		lpu.lading_page,
		(CASE WHEN o.order_id is not null then 1 else 0 end) as made_order
	FROM website_sessions ws
	JOIN lading_page_url lpu ON lpu.website_session_id = ws.website_session_id
	LEFT JOIN orders o ON o.website_session_id = ws.website_session_id
)
SELECT 
	utm_source,
	utm_campaign,
	lading_page,
	COUNT(website_session_id) AS Session,
	SUM(made_order) AS total_orders,
	ROUND(SUM(made_order)*1.0/COUNT(website_session_id),4)*100 AS CR
FROM session_data
GROUP BY utm_source, utm_campaign, lading_page
ORDER BY utm_source, CR DESC

--Product Analyst:
---Product Performance:
SELECT 
	o.product_id,
	p.product_name,
	COUNT(DISTINCT o.order_id) as orders,
	SUM(o.price_usd) as revenue,
	ROUND(SUM(o.price_usd)*1.0/COUNT(DISTINCT o.order_id),4) AS AOV
FROM order_items o
JOIN products p ON p.product_id = o.product_id
GROUP BY o.product_id,p.product_name

---REFUND RATE:
SELECT 
	p.product_name,
	COUNT(DISTINCT o.order_item_id) AS Total_orders,
	COUNT(DISTINCT oir.order_item_id) AS Total_refund,
	ROUND(COUNT(DISTINCT oir.order_item_id)*1.0/COUNT(DISTINCT o.order_item_id),4)*100 AS refund_rate
FROM order_items o
LEFT JOIN products p ON o.product_id = p.product_id
LEFT JOIN order_item_refunds oir ON o.order_item_id = oir.order_item_id
GROUP BY p.product_name
