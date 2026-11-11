with raw_orders as (
    select * from {{ source("jaffle_shop", "orders") }}
),
raw_customers as (
    select * from {{ source("jaffle_shop", "customers") }}
),
raw_payment as (
    select * from {{ source("stripe", "payment") }}
),
order_payment_agg as (
    select
        orderid as order_id,
        max(created) as payment_finalized_date,
        sum(amount) / 100.0 as total_amount_paid
    from raw_payment
    where status <> 'fail'
    group by 1
),
paid_orders as (
    select
        o.id as order_id,
        o.user_id as customer_id,
        o.order_date as order_placed_at,
        o.status as order_status,
        p.total_amount_paid,
        p.payment_finalized_date,
        c.first_name as customer_first_name,
        c.last_name as customer_last_name
    from raw_orders as o
    left join order_payment_agg p on o.id = p.order_id
    left join raw_customers c on o.user_id = c.id
),
customer_orders as (
    select
        c.id as customer_id,
        min(o.order_date) as first_order_date,
        max(o.order_date) as most_recent_order_date,
        count(o.id) as number_of_orders
    from raw_customers c
    left join raw_orders as o on o.user_id = c.id
    group by 1
),
customer_ltv as (
    select 
        p.order_id, 
        sum(t2.total_amount_paid) as customer_ltv
    from paid_orders p
    left join paid_orders t2
        on p.customer_id = t2.customer_id
        and p.order_id >= t2.order_id
    group by 1
    order by p.order_id
)
select
    p.*,
    row_number() over (order by p.order_id) as transaction_seq,
    row_number() over (partition by customer_id order by p.order_id) as customer_sales_seq,
    case when c.first_order_date = p.order_placed_at then 'new' else 'return' end as customer_type,
    ltv.customer_ltv,
    c.first_order_date
from paid_orders p
left join customer_orders as c using (customer_id)
left outer join customer_ltv ltv on ltv.order_id = p.order_id
order by order_id
