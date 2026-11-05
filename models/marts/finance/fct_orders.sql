with orders as (
    select * from {{ ref('stg_jaffle_shop__orders') }}
),
payments as (
    select * from {{ ref('stg_stripe__payments') }}
),
order_payments as (
    select
        order_id,
        sum (case when status = 'success' then amount end) as amount
    from payments
    group by order_id
)
select
    o.order_id,
    o.customer_id,
    o.order_date,
    coalesce(p.amount,0) as amount
from orders as o
    left join order_payments as p
        on o.order_id = p.order_id