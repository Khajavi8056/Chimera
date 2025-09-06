//+------------------------------------------------------------------+
//|                                                       tester.mqh |
//|                                Copyright 2025, HipoAlgoritm v1.5 |
//|                                                t.me/hipoalgoritm |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, HipoAlgoritm v1.5"
#property link      "t.me/hipoalgoritm"
//+------------------------------------------------------------------+



//--- گروه: تنظیمات بهینه‌سازی سفارشی ---
input group "  تنظیمات بهینه‌سازی سفارشی"; // گروه بهینه‌سازی
input int InpMinTradesPerYear = 30; // حداقل تعداد معاملات قابل قبول در یک سال
input int InpMaxAcceptableDrawdown = 15; // حداکثر دراوداون قابل قبول


//+------------------------------------------------------------------+
//| تابع اصلی رویداد تستر که امتیاز نهایی را محاسبه می‌کند.          |
//+------------------------------------------------------------------+
double OnTester()
{
   // --- 1. گرفتن تمام آمارهای استاندارد مورد نیاز ---
   double total_trades         = TesterStatistics(STAT_TRADES); // تعداد معاملات
   double net_profit           = TesterStatistics(STAT_PROFIT); // سود خالص
   double profit_factor        = TesterStatistics(STAT_PROFIT_FACTOR); // فاکتور سود
   double sharpe_ratio         = TesterStatistics(STAT_SHARPE_RATIO); // شارپ ریتو
   double max_balance_drawdown_percent = TesterStatistics(STAT_BALANCE_DDREL_PERCENT); // حداکثر دراوداون

   // --- 2. محاسبه حداقل تعداد معاملات مورد نیاز (بدون تغییر) ---
   datetime startDate = 0, endDate = 0; // تاریخ شروع و پایان
   if(HistoryDealsTotal() > 0) // چک معاملات
     {
      startDate = (datetime)HistoryDealGetInteger(0, DEAL_TIME); // تاریخ شروع
      endDate   = (datetime)HistoryDealGetInteger(HistoryDealsTotal() - 1, DEAL_TIME); // تاریخ پایان
     }
   double duration_days = (endDate > startDate) ? double(endDate - startDate) / (24.0 * 3600.0) : 1.0; // محاسبه روزها
   double required_min_trades = floor((duration_days / 365.0) * InpMinTradesPerYear); // حداقل معاملات
   if(required_min_trades < 10) required_min_trades = 10; // حداقل 10

   // --- 3. فیلترهای ورودی نهایی (بدون تغییر) ---
   if(total_trades < required_min_trades || profit_factor < 1.1 || sharpe_ratio <= 0 || net_profit <= 0) // چک فیلترها
     {
      return 0.0; // بازگشت صفر
     }

   // --- 4. محاسبه معیارهای پیشرفته (بدون تغییر) ---
   double r_squared = 0, downside_consistency = 0; // متغیرهای پیشرفته
   CalculateAdvancedMetrics(r_squared, downside_consistency); // محاسبه پیشرفته

   // --- 5. *** مهندسی امتیاز: محاسبه "ضریب مجازات" با منحنی کسینوسی *** ---
   double drawdown_penalty_factor = 0.0; // ضریب مجازات
   if (max_balance_drawdown_percent < InpMaxAcceptableDrawdown && InpMaxAcceptableDrawdown > 0)  // چک دراوداون
   {
      // دراودان رو به یک زاویه بین 0 تا 90 درجه (π/2 رادیان) تبدیل می‌کنیم
      double angle = (max_balance_drawdown_percent / InpMaxAcceptableDrawdown) * (M_PI / 2.0); // محاسبه زاویه
      
      // ضریب مجازات، کسینوس اون زاویه است. هرچی زاویه (دراودان) بیشتر، کسینوس (امتیاز) کمتر
      drawdown_penalty_factor = cos(angle); // محاسبه کسینوس
   }
   // اگر دراودان بیشتر از حد مجاز باشه، ضریب صفر می‌مونه و کل پاس رد میشه

   // --- 6. محاسبه امتیاز نهایی جامع با فرمول جدید و پیوسته ---
   double final_score = 0.0; // امتیاز نهایی
   if(drawdown_penalty_factor > 0) // چک مجازات
   {
      // استفاده از log برای نرمال‌سازی و جلوگیری از تاثیر بیش از حد اعداد بزرگ
      double trades_factor = log(total_trades + 1); // +1 برای جلوگیری از log(0)
      double net_profit_factor = log(net_profit + 1); // فاکتور سود خالص

      final_score = (profit_factor * sharpe_ratio * r_squared * downside_consistency * trades_factor * net_profit_factor) 
                     * drawdown_penalty_factor; // ضرب در ضریب مجازات جدید و هوشمند
   }

   // --- 7. چاپ نتیجه برای دیباگ ---
   PrintFormat("نتیجه: Trades=%d, PF=%.2f, Sharpe=%.2f, R²=%.3f, BalDD=%.2f%%, Penalty=%.2f -> امتیاز: %.4f",
               (int)total_trades, profit_factor, sharpe_ratio, r_squared, max_balance_drawdown_percent, drawdown_penalty_factor, final_score); // لاگ نتیجه

   return final_score; // بازگشت امتیاز
}

// تابع CalculateAdvancedMetrics بدون هیچ تغییری باقی می‌ماند
void CalculateAdvancedMetrics(double &r_squared, double &downside_consistency)
{
   r_squared = 0; // اولیه r_squared
   downside_consistency = 1.0; // اولیه ثبات

   if(!HistorySelect(0, TimeCurrent())) return; // انتخاب تاریخچه
   uint total_deals = HistoryDealsTotal(); // تعداد معاملات
   if(total_deals < 5) return; // چک حداقل معاملات

   EquityPoint equity_curve[]; // آرایه منحنی اکویتی
   ArrayResize(equity_curve, (int)total_deals + 2); // تغییر اندازه

   double final_balance = AccountInfoDouble(ACCOUNT_BALANCE); // بالانس نهایی
   double net_profit = TesterStatistics(STAT_PROFIT); // سود خالص
   double initial_balance = final_balance - net_profit; // بالانس اولیه
   
   double current_balance = initial_balance; // بالانس فعلی
   equity_curve[0].time      = (datetime)HistoryDealGetInteger(0, DEAL_TIME) - 1; // زمان اولیه
   equity_curve[0].balance   = current_balance; // بالانس اولیه

   int equity_points = 1; // شمارنده نقاط
   for(uint i = 0; i < total_deals; i++) // حلقه معاملات
     {
      ulong ticket = HistoryDealGetTicket(i); // تیکت
      if(ticket > 0) // چک تیکت
        {
         if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT) // چک خروج
           {
            current_balance += HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_COMMISSION) + HistoryDealGetDouble(ticket, DEAL_SWAP); // آپدیت بالانس
            equity_curve[equity_points].time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME); // زمان نقطه
            equity_curve[equity_points].balance = current_balance; // بالانس نقطه
            equity_points++; // افزایش
           }
        }
     }
   ArrayResize(equity_curve, equity_points); // تغییر اندازه نهایی
   if(equity_points < 3) return; // چک حداقل نقاط
   
   double sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0, sum_y2 = 0; // متغیرهای محاسباتی
   for(int i = 0; i < equity_points; i++) // حلقه نقاط
     {
      double x = i + 1.0; double y = equity_curve[i].balance; // x و y
      sum_x += x; sum_y += y; sum_xy += x * y; sum_x2 += x*x; sum_y2 += y*y; // جمع‌ها
     }
   double n = equity_points; // تعداد نقاط
   double den_part1 = (n*sum_x2) - (sum_x*sum_x); // محاسبه دنومیناتور 1
   double den_part2 = (n*sum_y2) - (sum_y*sum_y); // محاسبه دنومیناتور 2
   if(den_part1 > 0 && den_part2 > 0) // چک مثبت بودن
     {
      double r = ((n*sum_xy) - (sum_x*sum_y)) / sqrt(den_part1 * den_part2); // محاسبه r
      r_squared = r*r; // محاسبه r_squared
     }

   MonthlyTrades monthly_counts[]; // آرایه ماهانه
   int total_months = 0; // شمارنده ماه‌ها
   
   for(uint i=0; i<total_deals; i++) // حلقه معاملات
     {
      ulong ticket = HistoryDealGetTicket(i); // تیکت
      if(ticket > 0 && HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT) // چک خروج
        {
         datetime deal_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME); // زمان معامله
         MqlDateTime dt; // ساختار زمان
         TimeToStruct(deal_time, dt); // تبدیل زمان
         
         int month_idx = -1; // ایندکس ماه
         for(int j=0; j<total_months; j++) { // جستجو ماه
            if(monthly_counts[j].year == dt.year && monthly_counts[j].month == dt.mon) { // چک ماه و سال
               month_idx = j;
               break;
            }
         }
         
         if(month_idx == -1) { // اگر جدید
            ArrayResize(monthly_counts, total_months + 1); // تغییر اندازه
            monthly_counts[total_months].year = dt.year; // سال
            monthly_counts[total_months].month = dt.mon; // ماه
            monthly_counts[total_months].count = 1; // شمارنده
            total_months++; // افزایش
         } else { // افزایش شمارنده
            monthly_counts[month_idx].count++;
         }
        }
     }

   if(total_months <= 1) { // چک حداقل ماه‌ها
      downside_consistency = 1.0; // مقدار پیش‌فرض
      return;
   }

   double target_trades_per_month = InpMinTradesPerYear / 12.0; // هدف ماهانه
   if (target_trades_per_month < 1) target_trades_per_month = 1; // حداقل 1


   double sum_of_squared_downside_dev = 0; // جمع مربعات انحراف
   for(int i = 0; i < total_months; i++) { // حلقه ماه‌ها
      if(monthly_counts[i].count < target_trades_per_month) { // چک کمتر از هدف
         double deviation = target_trades_per_month - monthly_counts[i].count; // انحراف
         sum_of_squared_downside_dev += deviation * deviation; // جمع مربعات
      }
   }

   double downside_variance = sum_of_squared_downside_dev / total_months; // واریانس
   double downside_deviation = sqrt(downside_variance); // انحراف استاندارد

   downside_consistency = 1.0 / (1.0 + downside_deviation); // محاسبه ثبات
}



//+------------------------------------------------------------------+
//|     بخش بهینه‌سازی سفارشی (Custom Optimization) نسخه 10.0 - نهایی   |
//|      با "منحنی مجازات دراوداون پیوسته" (Continuous Penalty Curve)     |
//+------------------------------------------------------------------+

//--- ساختارهای کمکی (بدون تغییر)
struct EquityPoint
{
   datetime time; // زمان نقطه
   double   balance; // بالانس نقطه
};
struct MonthlyTrades
{
   int      year; // سال
   int      month; // ماه
   int      count; // شمارنده
};
