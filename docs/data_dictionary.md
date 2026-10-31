# Data dictionary

## Source: `data/raw/online_retail.zip` (UCI Online Retail)
Transactions of a UK-based online gift retailer, 1 Dec 2010 to 9 Dec 2011. **541,909 rows**, 8 columns: `InvoiceNo` (prefix `C` = cancellation), `StockCode`, `Description`, `Quantity`, `InvoiceDate`, `UnitPrice`, `CustomerID` (25% blank), `Country`.

## Warehouse tables (`data/sales.db`)
| Table | Grain | Notes |
|---|---|---|
| `raw_online_retail` | source row | loaded as-is |
| `stg_retail` | de-duplicated row | typed, classified, `exclusion_reason` |
| `data_quality_log` | cleaning step | row counts and value at each step |
| `ref_product_group_rules` | keyword rule | drives `dim_product.product_group` |
| `fact_sales` | invoice line | sales + returns; `revenue` signed |
| `dim_date` | calendar day | `is_complete_month` = 0 for Dec 2011 |
| `dim_product` | stock code | most frequent description; heuristic `product_group` |
| `dim_customer` | customer | `customer_key` 0 = guest; first/last order, cohort month |
| `dim_country` | country | mapped to `region` |

## `fact_sales` columns
| Column | Description |
|---|---|
| `sales_key` | surrogate key |
| `invoice_no` | invoice number (text) |
| `date_key` | `YYYYMMDD`, joins `dim_date` |
| `invoice_hour` | hour of day 0-23 |
| `product_key` | stock code (text) |
| `customer_key` | customer ID; **0 = guest checkout** |
| `country` | invoice country |
| `transaction_type` | `Sale` or `Return` |
| `quantity` | signed units (returns negative) |
| `unit_price` | price per unit |
| `revenue` | `quantity x unit_price`, signed |

## Cleaning rules (see `data_quality_log`)
| Step | Rows | Rule |
|---|---:|---|
| Raw | 541,909 | |
| Duplicates removed | -5,268 | exact duplicates across all 8 columns |
| Bad-debt adjustment | -3 | invoices starting `A` |
| Non-product codes | -2,986 | `POST`, `DOT`, `M`, `D`, `S`, `B`, `BANK CHARGES`, `AMAZONFEE`, `CRUK`, gift vouchers... |
| Zero / negative price | -2,480 | free items / stock write-offs |
| Reversed bulk orders | -4 | two 74K-81K-unit orders fully cancelled within minutes |
| **Fact rows kept** | **531,168** | |

## Assumptions to be aware of
- Exact duplicate rows are treated as errors; they could occasionally be genuine repeat scans (removing them lowers total value by about 0.2%).
- Currency is not stated in the source; shown as £ because the retailer is UK-based.
- `product_group` is a keyword heuristic (the source has no category); "Other" is ~12% of net revenue.
- December 2011 contains only 9 days; month-over-month growth is suppressed for it.
- 25% of lines have no `CustomerID`; they are kept as a "Guest" customer for revenue totals, but excluded from customer counts.
