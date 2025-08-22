// Engine_Hoplite.mqh
// موتور دفاعی بازگشت به میانگین - این فایل منطق سیگنال و خروج Hoplite را پیاده‌سازی می‌کند

#ifndef ENGINE_HOPLITE_MQH  // بررسی برای جلوگیری از تعریف مجدد هدر - جلوگیری از کامپایل چندباره
#define ENGINE_HOPLITE_MQH  // تعریف گارد برای جلوگیری از تعریف مجدد


#include "Settings.mqh"  // شامل تنظیمات - دسترسی به ورودی‌ها
#include "Logging.mqh"  // شامل لاگ - سیستم لاگینگ
#include "MoneyManagement.mqh"  // شامل مدیریت پول - مدیریت ریسک
#include "Engine_Kensei.mqh"  // شامل موتور Kensei - موتور تهاجمی

// تعریف enum برای سیگنال‌ها - enum برای انواع سیگنال
//enum SIGNAL { SIGNAL_NONE, SIGNAL_LONG, SIGNAL_SHORT };  // سیگنال هیچ، خرید، فروش - انواع سیگنال ممکن

// تابع برای دریافت سیگنال Hoplite - تولید سیگنال بر اساس شرایط BB و RSI، هندل‌ها را دریافت می‌کند
SIGNAL GetHopliteSignal(string symbol, int bb_handle, int rsi_handle, int adx_handle)
{
   Log("شروع بررسی سیگنال Hoplite برای نماد: " + symbol);  // لاگ شروع بررسی سیگنال - ثبت شروع فرآیند
   if (bb_handle == INVALID_HANDLE) { LogError("هندل BB نامعتبر برای " + symbol); return SIGNAL_NONE; }  // چک هندل BB معتبر - خطا اگر نامعتبر
   if (rsi_handle == INVALID_HANDLE) { LogError("هندل RSI نامعتبر برای " + symbol); return SIGNAL_NONE; }  // چک هندل RSI معتبر - خطا اگر نامعتبر
   if (adx_handle == INVALID_HANDLE) { LogError("هندل ADX نامعتبر برای " + symbol); return SIGNAL_NONE; }  // چک هندل ADX معتبر - خطا اگر نامعتبر
   double bb_upper[1], bb_lower[1], bb_mid[1];  // آرایه‌های تک عنصری برای BB - بافرهای BB
   double rsi[1], adx[1];  // آرایه‌های RSI و ADX - بافرهای RSI و ADX
   double close[1];  // آرایه قیمت بسته فعلی - بافر close
   if (CopyBuffer(bb_handle, 0, 0, 1, bb_mid) <= 0) { LogError("خطا در کپی BB میانی برای " + symbol); return SIGNAL_NONE; }  // کپی خط میانی از هندل - دریافت mid
   if (CopyBuffer(bb_handle, 1, 0, 1, bb_upper) <= 0) { LogError("خطا در کپی BB بالایی برای " + symbol); return SIGNAL_NONE; }  // کپی باند بالایی از هندل - دریافت upper
   if (CopyBuffer(bb_handle, 2, 0, 1, bb_lower) <= 0) { LogError("خطا در کپی BB پایینی برای " + symbol); return SIGNAL_NONE; }  // کپی باند پایینی از هندل - دریافت lower
   if (CopyBuffer(rsi_handle, 0, 1, 1, rsi) <= 0) { LogError("خطا در کپی RSI برای " + symbol); return SIGNAL_NONE; }  // کپی RSI از هندل - دریافت RSI
   if (CopyBuffer(adx_handle, 0, 1, 1, adx) <= 0) { LogError("خطا در کپی ADX برای " + symbol); return SIGNAL_NONE; }  // کپی ADX از هندل - دریافت ADX
   if (CopyClose(symbol, Inp_Hoplite_Timeframe, 0, 1, close) < 1) { LogError("خطا در کپی قیمت بسته فعلی برای " + symbol); return SIGNAL_NONE; }  // کپی قیمت بسته فعلی - دریافت close
   if (adx[0] >= Inp_Hoplite_ADX_Threshold) 
   {
      Log("بازار رونددار تشخیص داده شد (ADX بالا) - بدون سیگنال برای " + symbol);  // لاگ فیلتر رژیم بازار - ثبت رونددار
      return SIGNAL_NONE;  // بازگشت بدون سیگنال - NONE به دلیل ADX
   }
   if (close[0] < bb_lower[0] && rsi[0] < Inp_Hoplite_RSI_Oversold) 
   {
      LogSignal(symbol, "Hoplite", "خرید");  // لاگ سیگنال خرید - ثبت سیگنال
      return SIGNAL_LONG;  // بازگشت سیگنال خرید - LONG
   }
   if (close[0] > bb_upper[0] && rsi[0] > Inp_Hoplite_RSI_Overbought) 
   {
      LogSignal(symbol, "Hoplite", "فروش");  // لاگ سیگنال فروش - ثبت سیگنال
      return SIGNAL_SHORT;  // بازگشت سیگنال فروش - SHORT
   }
   Log("هیچ سیگنالی در Hoplite برای " + symbol);  // لاگ عدم سیگنال - ثبت عدم تولید
   return SIGNAL_NONE;  // بازگشت بدون سیگنال - NONE
}

// تابع مدیریت خروج برای Hoplite - مدیریت خروج معاملات Hoplite، هندل BB را دریافت می‌کند
void ManageHopliteExit(ulong ticket, int bb_handle)
{
   Log("شروع مدیریت خروج Hoplite برای تیکت: " + IntegerToString(ticket));  // لاگ شروع مدیریت خروج - ثبت شروع
   if (!OrderSelect(ticket, SELECT_BY_TICKET)) { LogError("خطا در انتخاب سفارش برای خروج Hoplite"); return; }  // انتخاب سفارش و چک - خطا اگر شکست
   string symbol = OrderSymbol();  // نماد سفارش - دریافت نماد
   int type = OrderType();  // نوع سفارش - دریافت نوع
   if (Inp_ExitLogic == EXIT_DYNAMIC)  // اگر خروج دینامیک - چک منطق
   {
      if (bb_handle == INVALID_HANDLE) { LogError("هندل BB نامعتبر برای خروج در " + symbol); return; }  // چک هندل معتبر - خطا اگر نامعتبر
      double bb_mid[1];  // بافر BB میانی فعلی - آرایه mid
      if (CopyBuffer(bb_handle, 0, 0, 1, bb_mid) <= 0) { LogError("خطا در کپی BB برای خروج در " + symbol); return; }  // کپی BB فعلی از هندل - دریافت mid
      double current_price = (type == OP_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);  // قیمت فعلی بازار - دریافت قیمت
      bool close_cond = (type == OP_BUY && current_price >= bb_mid[0]) || (type == OP_SELL && current_price <= bb_mid[0]);  // شرط بستن معامله - چک شرط
      if (close_cond)
      {
         double close_price = (type == OP_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);  // قیمت بستن معامله - دریافت قیمت بستن
         if (OrderClose(ticket, OrderLots(), close_price, 3, clrRed))
            LogCloseTrade(ticket, "رسیدن به خط میانی BB");  // لاگ بستن موفق معامله - ثبت موفقیت
         else
            LogError("خطا در بستن معامله دینامیک برای تیکت " + IntegerToString(ticket) + ": " + IntegerToString(GetLastError()));  // لاگ خطا در بستن - ثبت خطا
      }
      else
      {
         Log("شرط بستن دینامیک برای تیکت " + IntegerToString(ticket) + " برقرار نیست.");  // لاگ عدم برقراری شرط - ثبت عدم شرط
      }
   }
   else if (Inp_ExitLogic == EXIT_RRR)  // اگر خروج RRR - چک منطق
   {
      Log("خروج RRR برای Hoplite - چک TP برای تیکت " + IntegerToString(ticket));  // لاگ چک TP - ثبت چک
   }
   Log("پایان مدیریت خروج Hoplite برای تیکت: " + IntegerToString(ticket));  // لاگ پایان مدیریت خروج - ثبت پایان
}

#endif  // پایان گارد تعریف - پایان هدر
