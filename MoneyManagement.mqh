// MoneyManagement.mqh
// نسخه بازنویسی شده توسط سقراط
// این فایل مسئولیت مدیریت پول، محاسبه ریسک، و اجرای دستورات معاملاتی را بر عهده دارد.
// خطاها برطرف شده و منطق برای استحکام و خوانایی بیشتر بهینه شده است.

// جلوگیری از تکرار تعریف هدر
#ifndef MONEY_MANAGEMENT_MQH
#define MONEY_MANAGEMENT_MQH

// اینکلود فایل‌های لازم
#include "Settings.mqh" // تنظیمات ورودی و ثابت‌ها
#include "Logging.mqh"   // سیستم پیشرفته لاگینگ
#include <Trade\Trade.mqh>   // کتابخانه استاندارد MQL5 برای عملیات معاملاتی

// تعریف متغیرهای خارجی (extern) - به کامپایلر می‌گوییم این متغیرها در فایل اصلی (.mq5) تعریف شده‌اند
extern double g_peak_equity;    // برای محاسبه افت سرمایه از اوج
extern double g_Kensei_Weight;  // وزن نرمال‌شده موتور کنسی
extern double g_Hoplite_Weight; // وزن نرمال‌شده موتور هاپلیت

// --- توابع کمکی ---

// این تابع جدید جایگزین PositionSelectByMagic که وجود ندارد، می‌شود
// چک می‌کند آیا پوزیشنی با نماد و مجیک نامبر مشخصی از قبل باز است یا نه
bool PositionExists(string symbol, ulong magic_number)
{
   // حلقه از آخر به اول (روش استاندارد و امن برای کار با لیست پوزیشن‌ها)
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      // اگر بتوانیم اطلاعات پوزیشن را با ایندکس i بگیریم
      if(PositionGetTicket(i) > 0)
      {
         // چک می‌کنیم که هم نماد و هم مجیک نامبر با ورودی ما یکی باشد
         if(PositionGetString(POSITION_SYMBOL) == symbol && PositionGetInteger(POSITION_MAGIC) == magic_number)
         {
            return true; // اگر پوزیشن پیدا شد، true را برمی‌گردانیم و از تابع خارج می‌شویم
         }
      }
   }
   return false; // اگر حلقه تمام شد و چیزی پیدا نشد، یعنی پوزیشن وجود ندارد
}


// --- توابع اصلی مدیریت پول و ریسک ---

// محاسبه حجم لات بر اساس درصد ریسک و فاصله حد ضرر
double CalculateLotSize(string symbol, double risk_percent, double sl_distance_price)
{
   Log("شروع محاسبه حجم لات برای " + symbol + " با ریسک " + DoubleToString(risk_percent, 2) + "% و فاصله SL " + DoubleToString(sl_distance_price, _Digits));
   
   // گرفتن اطلاعات ضروری از نماد معاملاتی
   double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);       // حداقل گام تغییر حجم (مثلا 0.01)
   double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE); // ارزش هر تیک حرکت قیمت
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);               // اندازه یک پوینت

   // چک کردن مقادیر برای جلوگیری از خطای تقسیم بر صفر
   if(point == 0 || tick_value == 0 || sl_distance_price <= 0)
   {
      LogError("اطلاعات نماد نامعتبر یا فاصله SL صفر برای " + symbol);
      return 0.0;
   }

   // محاسبه مقدار ریسک به پول (مثلا ۱٪ از ۱۰۰۰۰ دلار می‌شود ۱۰۰ دلار)
   double risk_amount = AccountInfoDouble(ACCOUNT_BALANCE) * risk_percent / 100.0;
   // محاسبه میزان ضرر به ازای هر ۱ لات استاندارد
   double loss_per_lot = (sl_distance_price / point) * tick_value;

   if(loss_per_lot <= 0)
   {
      LogError("میزان ضرر به ازای هر لات نامعتبر است (" + DoubleToString(loss_per_lot, 2) + ") برای " + symbol);
      return 0.0;
   }

   // محاسبه حجم لات خام و گرد کردن آن به پایین بر اساس گام مجاز نماد
   double lots = risk_amount / loss_per_lot;
   lots = MathFloor(lots / lot_step) * lot_step;
   
   Log("حجم لات نهایی محاسبه شده: " + DoubleToString(lots, 2));
   return lots;
}

// محاسبه افت سرمایه فعلی از آخرین اوج ثبت شده
double CalculateCurrentDrawdown()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY); // موجودی شناور فعلی
   // اگر اکوییتی فعلی از اوج قبلی بیشتر باشد، اوج جدید را ثبت می‌کنیم
   if (equity > g_peak_equity) 
   {
      g_peak_equity = equity;
   }
   // محاسبه درصد افت سرمایه
   double dd = (g_peak_equity > 0) ? (g_peak_equity - equity) / g_peak_equity : 0.0;
   return dd;
}

// چک می‌کند آیا افت سرمایه از حد مجاز فراتر رفته است یا نه
bool IsPortfolioDrawdownExceeded()
{
   double current_dd = CalculateCurrentDrawdown();
   LogDrawdown(current_dd); // ثبت افت سرمایه در لاگ
   
   bool exceeded = current_dd >= Inp_MaxPortfolioDrawdown; // مقایسه با حد مجاز
   if (exceeded)
   {
      Log("!!! هشدار حیاتی: افت سرمایه از حد مجاز ("+DoubleToString(Inp_MaxPortfolioDrawdown*100, 2)+"%) فراتر رفت. مقدار فعلی: " + DoubleToString(current_dd * 100, 2) + "%");
   }
   return exceeded;
}

// تابع اصلی برای باز کردن یک معامله جدید
void OpenTrade(string symbol, SIGNAL sig, int engine_id, int atr_handle)
{
   if (sig == SIGNAL_NONE) return; // اگر سیگنالی وجود ندارد، خارج شو

   // چک کردن پوزیشن تکراری با استفاده از تابع کمکی جدید
   ulong magic_number_to_check = Inp_BaseMagicNumber + engine_id;
   if(PositionExists(symbol, magic_number_to_check))
   {
      Log("پوزیشن باز برای موتور " + (engine_id == 1 ? "Kensei" : "Hoplite") + " روی نماد " + symbol + " از قبل وجود دارد. معامله جدید باز نشد.");
      return;
   }

   Log("تلاش برای باز کردن معامله در " + symbol + " از موتور " + (engine_id == 1 ? "Kensei" : "Hoplite"));

   if (atr_handle == INVALID_HANDLE) { LogError("هندل ATR نامعتبر برای باز کردن معامله در " + symbol); return; }
   
   double atr_value[1];
   if (CopyBuffer(atr_handle, 0, 1, 1, atr_value) <= 0) { LogError("خطا در کپی ATR برای باز کردن معامله در " + symbol); return; }
   
   // محاسبه فاصله حد ضرر بر اساس موتور مربوطه
   double sl_distance = 0.0;
   if (engine_id == 1) // موتور Kensei
   {
      sl_distance = atr_value[0] * Inp_Kensei_ATR_Multiplier;
   }
   else // موتور Hoplite
   {
      sl_distance = atr_value[0] * Inp_Hoplite_StopLoss_ATR_Multiplier;
   }
   
   // استفاده از وزن نرمال‌شده که در فایل اصلی محاسبه شده
   double weight = (engine_id == 1) ? g_Kensei_Weight : g_Hoplite_Weight;
   // محاسبه درصد ریسک نهایی با استفاده از پارامتر ورودی جدید و وزن موتور
   double risk_percent = Inp_Risk_Percent_Per_Trade * weight;
   
   Log("درصد ریسک نهایی محاسبه شده: " + DoubleToString(risk_percent, 2) + "%");

   double lots = CalculateLotSize(symbol, risk_percent, sl_distance);
   if (lots <= 0) { LogError("حجم لات محاسبه شده صفر یا نامعتبر است برای " + symbol); return; }

   // تعیین مشخصات معامله
   ENUM_ORDER_TYPE dir = (sig == SIGNAL_LONG) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double open_price = (dir == ORDER_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
   double sl = (dir == ORDER_TYPE_BUY) ? open_price - sl_distance : open_price + sl_distance;
   double tp = 0.0; // به طور پیش‌فرض حد سود نداریم (برای خروج دینامیک)
   
   // اگر منطق خروج بر اساس RRR باشد، حد سود را محاسبه می‌کنیم
   if (Inp_ExitLogic == EXIT_RRR)
   {
      tp = (dir == ORDER_TYPE_BUY) ? open_price + (sl_distance * Inp_RiskRewardRatio) : open_price - (sl_distance * Inp_RiskRewardRatio);
      Log("حد سود بر اساس RRR محاسبه شد: " + DoubleToString(tp, _Digits));
   }
   
   ulong magic = Inp_BaseMagicNumber + engine_id;
   string comment = COMMENT_PREFIX + (engine_id == 1 ? "Kensei" : "Hoplite");
   
   // اجرای معامله
   CTrade trade;
   trade.SetExpertMagicNumber(magic);
   if (trade.PositionOpen(symbol, dir, lots, open_price, sl, tp, comment))
   {
      LogOpenTrade(symbol, (sig == SIGNAL_LONG ? "خرید" : "فروش"), lots, sl, tp);
   }
   else
   {
      LogError("خطا در باز کردن معامله: " + IntegerToString(trade.ResultRetcode()) + " - " + trade.ResultComment());
   }
}

// پایان گارد
#endif
