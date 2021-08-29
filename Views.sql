/*
This is a view that show the parts whose stocks are running low.
Any part whose stock is less than the quantity of that part ordered last month is shown in this view.
*/


DROP VIEW IF EXISTS LowStock;

CREATE VIEW [LowStock] AS
with cte as (
select
	storeID, Sum(Quantity) as OrderAmtLastMonth, PartID
from
	OrderPart op
join Orders o on
	op.OrderID = o.OrderID
where
	OrderDate >= DATEADD(month, -1, getDate())
group by
	storeId, PartId)
select
	StockID,
	s.PartID,
	s.StoreId,
	Quantity as StockLeft,
	OrderAmtLastMonth
from
	stock s
join cte on
	s.storeId = cte.storeID
	and s.PartID = cte.PartID
where OrderAmtLastMonth > Quantity;


---


DROP VIEW IF EXISTS CustomerTargets;

/*
This is a view that show customers who have ordered the most from our shops but haven't ordered recently.
Any employee who hasn't ordered within the last month is show in this view and ranked by the amount they have spent in orders.
*/

CREATE VIEW [CustomerTargets] AS
select
	CustomerId,
	sum(SalePrice) * sum(op.Quantity) as Sale,
	max(OrderDate) as Latestorder,
	rank() over (order by sum(SalePrice) * sum(op.Quantity) desc) as ValueRank
from
	Orders o
inner join OrderPart op ON
	o.OrderID = op.OrderID
inner join price pr on
	op.PartID = pr.PartID
where
	pr.EndedAt IS NULL
group by
	CustomerId
having
	max(OrderDate) < DATEADD(day, -30, getDate());


----------------------
/*
This is a view that show the top 3 profitable part of each type of parts. 

*/
--Part
CREATE VIEW vwMostProfitPart AS 
with temp as 
(
SELECT --op.PartID,
	pa.partType, pa.name
	, SUM(op.Quantity)*(p.SalePrice -p.CostPrice) as Profit
	, Rank() Over (PARTITION by pa.PartType order by SUM(op.Quantity)*(p.SalePrice -p.CostPrice) Desc) as ranks
FROM OrderPart op 
JOIN Price p on p.partID = op.PartID 
JOIN part pa on pa.PartID = op.PartID 
Group by p.SalePrice, p.CostPrice,pa.partType, pa.name --,op.PartID
)

select distinct t.PartType,
	STUFF((SELECT ', ' + name
		FROM temp
		WHERE Ranks <= 3 
		FOR XML PATH('')) , 1, 2, '') as Top3Parts
	from temp t
	group by t.PartType, t.ranks --, t.PartID

----------------------------------------------------------------------------
--store

/*
This is a view that show the most profitable stores.
*/
CREATE VIEW vwMostProfitStore AS 
with temp as(
	SELECT op.PartID,o.StoreID
	, SUM(op.Quantity)*(p.SalePrice -p.CostPrice) as Profit
	--, Rank() Over (PARTITION by pa.PartType order by SUM(op.Quantity)*(p.SalePrice -p.CostPrice) Desc) as ranks
FROM OrderPart op 
JOIN Price p on p.partID = op.PartID 
Join orders o on o.OrderID = op.OrderID 
Group by op.PartID, p.SalePrice, p.CostPrice,o.StoreID)

SELECT t.storeid, SUM(t.profit) as StoreTotalProfit
from temp t
group by t.storeid