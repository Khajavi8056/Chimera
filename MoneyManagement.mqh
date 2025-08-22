// MoneyManagement.mqh
// مغز پورتفولیو برای مدیریت ریسک و حجم - این فایل مدیریت پول و ریسک را پیاده‌سازی می‌کند

#ifndef MONEY_MANAGEMENT_MQH  // بررسی برای جلوگیری از تعریف مجدد هدر - جلوگیری از کامپایل چندباره
#define MONEY_MANAGEMENT_MQH  // تعریف گارد برای جلوگیری از تعریف مجدد

#include <Settings.mqh>  // شامل کردن تنظیمات - دسترسی به پارامترها
#include <Logging.mqh>  // شامل کردن سیستم لاگ - برای لاگینگ
#include <Engine_Kensei.mqh>  // شامل موتور Kensei - برای SIGNAL
#include <Engine_Hoplite.mqh>  // شامل موتور Hoplite - برای SIGNAL
#include <Trade\Trade.mqh>  // شامل کتابخانه CTrade - برای ارسال معاملات رسمی

extern double g_peak_equity;  // اعلام متغیر سراسری g_peak_equity - تعریف شده در فایل اصلی

// تابع محاسبه حجم لات - محاسبه دقیق حجم بر اساس ریسک
double CalculateLotSize(string symbol, double risk_percent, double sl_pips)
{
   Log("محاسبه حجم لات برای " + symbol + " با ریسک " + DoubleToString(risk_percent, 2) + "% و SL " + DoubleToString(sl_pips, 1) + " پیپ");  // لاگ شروع محاسبه حجم - ثبت ورودی‌ها
   double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);  // دریافت استپ لات نماد - حداقل تغییر حجم
   double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);  // دریافت ارزش تیک - ارزش هر تیک
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);  // دریافت اندازه پوینت - کوچک‌ترین واحد قیمت
   if(point == 0 || tick_value == 0)  // جلوگیری از تقسیم بر صفر - چک مقادیر معتبر
   {
      LogError("اطلاعات نماد " + symbol + " برای محاسبه حجم نامعتبر است.");  // لاگ خطا - ثبت نامعتبر
      return 0.0;  // بازگشت صفر - حجم نامعتبر
   }
   double risk_amount = AccountInfoDouble(ACCOUNT_BALANCE) * risk_percent / 100.0;  // محاسبه مبلغ ریسک - بر اساس بالانس
   double sl_distance_points = sl_pips * 10;  // تبدیل پیپ به پوینت (برای اکثر جفت‌ارزها) - تنظیم اولیه
   long digits = SymbolInfoInteger(symbol, SYMBOL_DIGITS);  // دریافت تعداد digits نماد - دقت قیمت
   if(digits == 3 || digits == 5) sl_distance_points = sl_pips * 10;  // تنظیم برای نمادهای 3 یا 5 رقمی - تنظیم پوینت
   else sl_distance_points = sl_pips;  // تنظیم برای دیگر نمادها - تنظیم پوینت
   double sl_in_money = (sl_distance_points * point) * (tick_value / point);  // فرمول دقیق‌تر - محاسبه ارزش SL به پول
   if (sl_in_money == 0)  // چک صفر بودن - جلوگیری از تقسیم بر صفر
   {
      LogError("فاصله SL محاسبه شده برای " + symbol + " صفر است. حجم قابل محاسبه نیست.");  // لاگ خطا - ثبت صفر
      return 0.0;  // بازگشت صفر - حجم نامعتبر
   }
   double lots = risk_amount / sl_in_money;  // محاسبه حجم خام - تقسیم ریسک بر ارزش SL
   lots = MathFloor(lots / lot_step) * lot_step;  // گرد کردن به پایین بر اساس استپ لات - نرمال‌سازی حجم
   Log("حجم محاسبه شده: " + DoubleToString(lots, 2));  // لاگ حجم محاسبه شده - ثبت نتیجه
   return lots;  // بازگشت حجم - حجم نهایی
}

// تابع چک افت سرمایه پورتفولیو - چک آیا DD بیش از حد است
bool IsPortfolioDrawdownExceeded()
{
   double current_dd = CalculateCurrentDrawdown();  // محاسبه DD فعلی - فراخوانی تابع
   LogDrawdown(current_dd);  // لاگ DD فعلی - ثبت DD
   bool exceeded = current_dd > Inp_MaxPortfolioDrawdown;  // چک آیا DD بیش از حد مجاز است - مقایسه
   if (exceeded) Log("افت سرمایه بیش از حد مجاز تشخیص داده شد: " + DoubleToString(current_dd * 100, 2) + "%");  // لاگ اگر بیش از حد - ثبت هشدار
   return exceeded;  // بازگشت نتیجه چک - true/false
}

// تابع محاسبه DD فعلی - محاسبه drawdown
double CalculateCurrentDrawdown()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);  // اکویتی فعلی حساب - دریافت اکویتی
   if (equity > g_peak_equity) g_peak_equity = equity;  // به‌روزرسانی اوج سراسری - چک و بروزرسانی peak
   double dd = (g_peak_equity > 0) ? (g_peak_equity - equity) / g_peak_equity : 0.0;  // محاسبه DD (جلوگیری از تقسیم بر صفر) - فرمول DD
   Log("محاسبه DD فعلی: " + DoubleToString(dd * 100, 2) + "% با اوج اکویتی " + DoubleToString(g_peak_equity, 2));  // لاگ جزئیات محاسبه - ثبت محاسبه
   return dd;  // بازگشت DD - DD محاسبه شده
}

// تابع باز کردن معامله - باز کردن position با CTrade، هندل ATR را دریافت می‌کند
void OpenTrade(string symbol, SIGNAL sig, int engine_id, int atr_handle)
{
   if (sig == SIGNAL_NONE) { Log("هیچ سیگنالی برای باز کردن معامله در " + symbol); return; }  // بدون سیگنال، خروج - چک سیگنال
   Log("تلاش برای باز کردن معامله در " + symbol + " از موتور " + (engine_id == 1 ? "Kensei" : "Hoplite"));  // لاگ تلاش برای باز کردن - ثبت تلاش
   if (atr_handle == INVALID_HANDLE) { LogError("هندل ATR نامعتبر برای " + symbol); return; }  // چک هندل ATR معتبر - خطا اگر نامعتبر
   double sl_distance = 0.0;  // فاصله SL اولیه - مقدار اولیه
   double atr_value[1];  // بافر برای ATR - آرایه ATR
   if (CopyBuffer(atr_handle, 0, 0, 1, atr_value) <= 0) { LogError("خطا در کپی ATR برای باز کردن معامله در " + symbol); return; }  // کپی ATR از هندل - دریافت ارزش فعلی
   if (engine_id == 1)  // Kensei - شاخه Kensei
   {
      sl_distance = atr_value[0] * Inp_Kensei_ATR_Multiplier;  // محاسبه SL برای Kensei - استفاده از ATR
      Log("فاصله SL محاسبه شده برای Kensei: " + DoubleToString(sl_distance, _Digits));  // لاگ فاصله SL - ثبت مقدار
   }
   else  // Hoplite - شاخه Hoplite
   {
      sl_distance = atr_value[0] * Inp_Hoplite_StopLoss_ATR_Multiplier;  // محاسبه SL برای Hoplite - استفاده از ATR
      Log("فاصله SL محاسبه شده برای Hoplite: " + DoubleToString(sl_distance, _Digits));  // لاگ فاصله SL - ثبت مقدار
   }
   double weight = (engine_id == 1) ? Inp_Kensei_Weight : Inp_Hoplite_Weight;  // وزن تخصیص سرمایه - انتخاب وزن
   double risk_percent = 1.0 * weight;  // درصد ریسک (قابل تنظیم، اینجا 1% پایه ضربدر وزن) - محاسبه ریسک
   Log("درصد ریسک محاسبه شده: " + DoubleToString(risk_percent, 2) + "%");  // لاگ درصد ریسک - ثبت ریسک
   double sl_pips = sl_distance / _Point;  // تبدیل فاصله SL به پیپ - محاسبه پیپ
   double lots = CalculateLotSize(symbol, risk_percent, sl_pips);  // محاسبه حجم لات - فراخوانی تابع
   if (lots <= 0) { LogError("حجم لات نامعتبر برای " + symbol); return; }  // چک حجم معتبر - خروج اگر نامعتبر
   int dir = (sig == SIGNAL_LONG) ? OP_BUY : OP_SELL;  // جهت معامله (خرید یا فروش) - تعیین جهت
   double open_price = (dir == OP_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);  // قیمت باز کردن معامله - دریافت قیمت
   double sl = (dir == OP_BUY) ? open_price - sl_distance : open_price + sl_distance;  // تنظیم SL بر اساس جهت - محاسبه SL
   double tp = 0.0;  // TP اولیه صفر - مقدار اولیه TP
   if (Inp_ExitLogic == EXIT_RRR)  // اگر منطق RRR - شاخه RRR
   {
      tp = (dir == OP_BUY) ? open_price + (sl_distance * Inp_RiskRewardRatio) : open_price - (sl_distance * Inp_RiskRewardRatio);  // تنظیم TP بر اساس open_price - محاسبه TP صحیح
      Log("TP محاسبه شده برای RRR: " + DoubleToString(tp, _Digits));  // لاگ TP محاسبه شده - ثبت TP
   }
   ulong magic = Inp_BaseMagicNumber + engine_id;  // مجیک نامبر منحصر به موتور - تنظیم مجیک
   string comment = COMMENT_PREFIX + (engine_id == 1 ? "Kensei" : "Hoplite");  // کامنت معامله - تنظیم کامنت
   CTrade trade;  // ایجاد شیء CTrade - برای ارسال معامله
   if (dir == OP_BUY)  // اگر خرید - شاخه BUY
   {
      if (trade.PositionOpen(symbol, ORDER_TYPE_BUY, lots, 0, open_price, sl, tp, magic, comment, 3))  // ارسال معامله خرید - استفاده از CTrade
         LogOpenTrade(symbol, "خرید", lots, sl, tp);  // لاگ موفقیت - ثبت باز شدن
      else
         LogError("خطا در باز کردن معامله خرید: " + IntegerToString(trade.ResultRetcode()));  // لاگ خطا - ثبت خطا
   }
   else  // اگر فروش - شاخه SELL
   {
      if (trade.PositionOpen(symbol, ORDER_TYPE_SELL, lots, 0, open_price, sl, tp, magic, comment, 3))  // ارسال معامله فروش - استفاده از CTrade
         LogOpenTrade(symbol, "فروش", lots, sl, tp);  // لاگ موفقیت - ثبت باز شدن
      else
         LogError("خطا در باز کردن معامله فروش: " + IntegerToString(trade.ResultRetcode()));  // لاگ خطا - ثبت خطا
   }
}

#endif  // پایان گارد تعریف - پایان هدر
