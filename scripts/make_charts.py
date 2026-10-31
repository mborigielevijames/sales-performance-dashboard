"""Render README charts from the SQL result files (sql/results/*.csv)."""
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as mtick
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
R, IMG = ROOT / "sql" / "results", ROOT / "images"
IMG.mkdir(exist_ok=True)
NAVY, TEAL, ORANGE, GREY, GOLD = "#1F3A5F", "#2A9D8F", "#E76F51", "#9AA5B1", "#E9C46A"
plt.rcParams.update({"figure.dpi": 110, "savefig.dpi": 160, "savefig.bbox": "tight",
                     "axes.spines.top": False, "axes.spines.right": False, "axes.titleweight": "bold",
                     "axes.grid": True, "grid.alpha": .25, "axes.axisbelow": True, "font.size": 10})
k = lambda x, _: f"£{x/1e3:,.0f}K"
m = lambda x, _: f"£{x/1e6:,.1f}M"
rd = lambda n: pd.read_csv(R / f"{n}.csv")


def monthly():
    d = rd("q02_monthly_trend"); fig, ax = plt.subplots(figsize=(11, 4.4))
    cols = [NAVY if c else GREY for c in d.is_complete_month]
    ax.bar(d.year_month, d.net_revenue, color=cols)
    ax.yaxis.set_major_formatter(mtick.FuncFormatter(k)); ax.set_ylabel("Net revenue")
    ax2 = ax.twinx(); ax2.grid(False); ax2.spines["right"].set_visible(True)
    dd = d[d.is_complete_month == 1]
    ax2.plot(dd.year_month, dd.net_revenue_mom_pct, color=ORANGE, marker="o", lw=2)
    ax2.axhline(0, color=ORANGE, lw=.6, ls=":"); ax2.set_ylabel("MoM growth (%)", color=ORANGE)
    ax.set_title("Net revenue by month (grey = partial month, data ends 9 Dec 2011)")
    plt.setp(ax.get_xticklabels(), rotation=45, ha="right"); fig.tight_layout()
    fig.savefig(IMG / "01_monthly_net_revenue.png"); plt.close(fig)


def top_products():
    d = rd("q05_top_products_net").head(10).iloc[::-1]; fig, ax = plt.subplots(figsize=(9, 4.8))
    ax.barh(d.description.str.title(), d.net_revenue, color=TEAL)
    for i, v in enumerate(d.net_revenue): ax.text(v, i, f" £{v/1e3:,.0f}K", va="center", fontsize=9)
    ax.xaxis.set_major_formatter(mtick.FuncFormatter(k)); ax.grid(False); ax.set_xlim(0, d.net_revenue.max() * 1.15)
    ax.set_title("Top 10 products by net revenue"); fig.tight_layout()
    fig.savefig(IMG / "02_top_products.png"); plt.close(fig)


def groups():
    d = rd("q07_product_group_performance").iloc[::-1]; fig, ax = plt.subplots(1, 2, figsize=(11, 4.4), sharey=True)
    ax[0].barh(d.product_group, d.net_revenue, color=NAVY)
    for i, (v, p) in enumerate(zip(d.net_revenue, d.pct_of_total)): ax[0].text(v, i, f" {p:.0f}%", va="center", fontsize=9)
    ax[0].xaxis.set_major_formatter(mtick.FuncFormatter(m)); ax[0].set_title("Net revenue by product group"); ax[0].grid(False)
    ax[0].set_xlim(0, d.net_revenue.max() * 1.15)
    ax[1].barh(d.product_group, d.return_rate_pct, color=ORANGE)
    for i, v in enumerate(d.return_rate_pct): ax[1].text(v, i, f" {v:.1f}%", va="center", fontsize=9)
    ax[1].set_title("Return rate (% of gross)"); ax[1].grid(False); ax[1].set_xlim(0, d.return_rate_pct.max() * 1.2)
    fig.tight_layout(); fig.savefig(IMG / "03_product_groups.png"); plt.close(fig)


def geography():
    d = rd("q04_revenue_by_region_country"); intl = d[d.country != "United Kingdom"].head(10).iloc[::-1]
    fig, ax = plt.subplots(1, 2, figsize=(11, 4.4), gridspec_kw={"width_ratios": [1, 1.6]})
    uk = d[d.country == "United Kingdom"].pct_of_total.iloc[0]
    ax[0].pie([uk, 100 - uk], labels=["United Kingdom", "International"], colors=[NAVY, ORANGE],
              autopct="%1.1f%%", startangle=90, wedgeprops=dict(width=.4, edgecolor="white"), textprops={"fontsize": 9})
    ax[0].set_title("Share of net revenue")
    ax[1].barh(intl.country, intl.net_revenue, color=TEAL)
    for i, (v, a) in enumerate(zip(intl.net_revenue, intl.avg_order_value)): ax[1].text(v, i, f" £{v/1e3:,.0f}K  (AOV £{a:,.0f})", va="center", fontsize=8.5)
    ax[1].xaxis.set_major_formatter(mtick.FuncFormatter(k)); ax[1].grid(False); ax[1].set_xlim(0, intl.net_revenue.max() * 1.45)
    ax[1].set_title("Top 10 international markets"); fig.tight_layout(); fig.savefig(IMG / "04_geography.png"); plt.close(fig)


def customers():
    d = rd("q10_new_vs_returning_customers_by_month"); fig, ax = plt.subplots(figsize=(11, 4.2))
    ax.bar(d.year_month, d.returning_customers, color=NAVY, label="Returning")
    ax.bar(d.year_month, d.new_customers, bottom=d.returning_customers, color=GOLD, label="New")
    ax.set_title("Active registered customers: new vs returning"); ax.legend(frameon=False)
    plt.setp(ax.get_xticklabels(), rotation=45, ha="right"); fig.tight_layout()
    fig.savefig(IMG / "05_new_vs_returning.png"); plt.close(fig)


def timing():
    dow, hr = rd("q13_day_of_week_and_hour"), rd("q14_hourly_orders")
    fig, ax = plt.subplots(1, 2, figsize=(11, 3.8))
    ax[0].bar(dow.day_name, dow.orders, color=TEAL); ax[0].set_title("Orders by weekday (no Saturday trading in data)")
    ax[1].bar(hr.invoice_hour, hr.orders, color=NAVY); ax[1].set_title("Orders by hour of day"); ax[1].set_xlabel("Hour")
    fig.tight_layout(); fig.savefig(IMG / "06_order_timing.png"); plt.close(fig)


def reference_layout():
    kpi = rd("q01_executive_kpis").iloc[0]; mt = rd("q02_monthly_trend"); pg = rd("q07_product_group_performance")
    ct = rd("q04_revenue_by_region_country"); tp = rd("q05_top_products_net").head(8)
    fig = plt.figure(figsize=(16, 9), facecolor="#F4F6F8")
    fig.text(.02, .955, "Sales Performance Dashboard: Executive Overview", fontsize=19, fontweight="bold", color=NAVY)
    fig.text(.02, .925, "REFERENCE LAYOUT: Python render of the target Power BI page using the real SQL results. Rebuild in Power BI Desktop (see powerbi/BUILD_GUIDE.md).",
             fontsize=9.5, color="#B03A2E")
    tiles = [("Net revenue", f"£{kpi.net_revenue/1e6:,.2f}M"), ("Orders", f"{kpi.orders:,.0f}"), ("Avg order value", f"£{kpi.avg_order_value:,.0f}"),
             ("Active customers", f"{kpi.registered_customers:,.0f}"), ("Return rate", f"{kpi.return_rate_pct:.1f}%"), ("Units / order", f"{kpi.units_per_order:,.0f}")]
    for i, (lab, val) in enumerate(tiles):
        a = fig.add_axes([.02 + i * .1625, .80, .152, .10]); a.set_facecolor("white"); a.set_xticks([]); a.set_yticks([])
        a.text(.5, .62, val, ha="center", va="center", fontsize=20, fontweight="bold", color=NAVY)
        a.text(.5, .22, lab, ha="center", va="center", fontsize=10, color="#5D6D7E")
        for s in a.spines.values(): s.set_color("#D5D8DC")
    a = fig.add_axes([.04, .42, .55, .31]); a.set_facecolor("white")
    full = mt[mt.is_complete_month == 1]
    a.bar(full.year_month, full.net_revenue, color=NAVY)
    a.yaxis.set_major_formatter(mtick.FuncFormatter(k)); a.set_title("Net revenue by month (complete months)", loc="left"); plt.setp(a.get_xticklabels(), rotation=45, ha="right", fontsize=8)
    a = fig.add_axes([.67, .42, .30, .31]); a.set_facecolor("white"); p = pg.iloc[::-1]
    a.barh(p.product_group, p.net_revenue, color=TEAL); a.xaxis.set_major_formatter(mtick.FuncFormatter(m)); a.set_title("Net revenue by product group", loc="left"); a.tick_params(labelsize=8); a.grid(False)
    a = fig.add_axes([.25, .06, .34, .28]); a.set_facecolor("white"); t = tp.iloc[::-1]
    a.barh(t.description.str.title().str[:30], t.net_revenue, color=GOLD); a.xaxis.set_major_formatter(mtick.FuncFormatter(k)); a.set_title("Top products (net revenue)", loc="left"); a.tick_params(labelsize=8); a.grid(False)
    a = fig.add_axes([.67, .06, .30, .28]); a.set_facecolor("white"); c = ct[ct.country != "United Kingdom"].head(6).iloc[::-1]
    a.barh(c.country, c.net_revenue, color=ORANGE); a.xaxis.set_major_formatter(mtick.FuncFormatter(k)); a.set_title("Top international markets", loc="left"); a.tick_params(labelsize=8); a.grid(False)
    fig.text(.02, .30, "Slicers\n• Date range\n• Region\n• Product group\n• Customer type", fontsize=8.5, color="#5D6D7E", va="top")
    fig.savefig(IMG / "00_dashboard_reference_layout.png", facecolor=fig.get_facecolor()); plt.close(fig)


if __name__ == "__main__":
    for f in (monthly, top_products, groups, geography, customers, timing, reference_layout): f()
    print("charts written to", IMG)
