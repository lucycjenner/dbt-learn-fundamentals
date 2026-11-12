with orders as (
    select * from {{ ref('stg_jaffle_shop__orders') }}
),
customers as (
    select * from {{ ref('stg_jaffle_shop__customers') }}
),
payments as (
    select * from {{ ref('stg_stripe__payments') }}
),
order_payment_agg as (
    select
        order_id,
        max(payment_created_at) as payment_finalized_date,
        sum(payment_amount) / 100.0 as total_amount_paid
    from payments
    where payment_status <> 'fail'
    group by 1
),
paid_orders as (
    select
        o.order_id,
        o.customer_id,
        o.order_date as order_placed_at,
        o.order_status,
        p.total_amount_paid,
        p.payment_finalized_date,
        c.first_name as customer_first_name,
        c.last_name as customer_last_name
    from orders as o
    left join order_payment_agg p on o.order_id = p.order_id
    left join customers c on o.customer_id = c.customer_id
),
customer_orders as (
    select
        c.customer_id,
        min(o.order_date) as first_order_date,
        max(o.order_date) as most_recent_order_date,
        count(o.order_id) as number_of_orders
    from customers c
    left join orders as o on o.customer_id = c.customer_id
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
    p.order_id,
    p.customer_id,
    p.order_placed_at,
    p.order_status,
    p.total_amount_paid,
    p.payment_finalized_date,
    p.customer_first_name,
    p.customer_last_name,
    row_number() over (order by p.order_id) as transaction_seq,
    row_number() over (partition by customer_id order by p.order_id) as customer_sales_seq,
    case when c.first_order_date = p.order_placed_at then 'new' else 'return' end as customer_type,
    ltv.customer_ltv,
    c.first_order_date
from paid_orders p
left join customer_orders as c using (customer_id)
left outer join customer_ltv ltv on ltv.order_id = p.order_id
order by order_id
