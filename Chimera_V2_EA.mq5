// Chimera_V2_EA.mq5
// فایل اصلی اکسپرت - رهبر ارکستر - این فایل اصلی EA است که همه چیز را هماهنگ می‌کند

#property copyright "Chimera V2.0"  // کپی‌رایت - حقوق کپی
#property version   "2.00"  // نسخه - نسخه EA
#property strict  // حالت دقیق - strict mode

#include "Settings.mqh"  // شامل تنظیمات - دسترسی به ورودی‌ها
#include "Logging.mqh"  // شامل لاگ - سیستم لاگینگ
#include "MoneyManagement.mqh"  // شامل مدیریت پول - مدیریت ریسک
#include "Engine_Kensei.mqh"  // شامل موتور Kensei - موتور تهاجمی
#include "Engine_Hoplite.mqh"  // شامل موتور Hoplite - موتور دفاعی

// متغیرهای جهانی - متغیرهای سراسری EA
string kensei_syms[];  // آرایه نمادهای Kensei - لیست نمادها
datetime last_kensei_times[];  // آرایه زمان آخرین بررسی برای هر نماد Kensei - زمان‌های آخرین چک
string hoplite_syms[];  // آرایه نمادهای Hoplite - لیست نمادها
datetime last_hoplite_times[];  // آرایه زمان آخرین بررسی برای هر نماد Hoplite - زمان‌های آخرین چک
double g_peak_equity = 0;  // متغیر سراسری برای اوج اکویتی - برای محاسبه DD پایدار

// آرایه‌های هندل اندیکاتورها - برای بهینه‌سازی عملکرد، هندل‌ها یک بار ساخته می‌شوند
int g_kensei_ichi_handles[];  // آرایه هندل‌های ایچیموکو برای نمادهای Kensei - ذخیره هندل‌ها
int g_kensei_atr_handles[];  // آرایه هندل‌های ATR برای نمادهای Kensei - ذخیره هندل‌ها
int g_hoplite_bb_handles[];  // آرایه هندل‌های BB برای نمادهای Hoplite - ذخیره هندل‌ها
int g_hoplite_rsi_handles[];  // آرایه هندل‌های RSI برای نمادهای Hoplite - ذخیره هندل‌ها
int g_hoplite_adx_handles[];  // آرایه هندل‌های ADX برای نمادهای Hoplite - ذخیره هندل‌ها
int g_hoplite_atr_handles[];  // آرایه هندل‌های ATR برای نمادهای Hoplite - ذخیره هندل‌ها

// تابع ابتدایی - OnInit - ابتدایی‌سازی EA
int OnInit()
{
   Log("شروع اکسپرت Chimera V2.0");  // لاگ شروع اکسپرت - ثبت شروع
   LogInit();  // فراخوانی ابتدایی لاگ (باز کردن فایل) - باز کردن فایل لاگ
   int kensei_count = StringSplit(Inp_Kensei_Symbols, ',', kensei_syms);  // تقسیم رشته نمادهای Kensei - split به آرایه
   if (kensei_count <= 0) { LogError("خطا در تقسیم نمادهای Kensei: " + Inp_Kensei_Symbols); return INIT_FAILED; }  // چک تقسیم موفق - خطا اگر شکست
   ArrayResize(last_kensei_times, kensei_count);  // تغییر اندازه آرایه زمان‌ها برای Kensei - resize آرایه
   ArrayInitialize(last_kensei_times, 0);  // مقداردهی اولیه زمان‌ها به صفر - initialize
   int hoplite_count = StringSplit(Inp_Hoplite_Symbols, ',', hoplite_syms);  // تقسیم رشته نمادهای Hoplite - split به آرایه
   if (hoplite_count <= 0) { LogError("خطا در تقسیم نمادهای Hoplite: " + Inp_Hoplite_Symbols); return INIT_FAILED; }  // چک تقسیم موفق - خطا اگر شکست
   ArrayResize(last_hoplite_times, hoplite_count);  // تغییر اندازه آرایه زمان‌ها برای Hoplite - resize آرایه
   ArrayInitialize(last_hoplite_times, 0);  // مقداردهی اولیه زمان‌ها به صفر - initialize
   // مقداردهی اولیه هندل‌های Kensei - ایجاد هندل‌ها یک بار
   ArrayResize(g_kensei_ichi_handles, kensei_count);  // resize آرایه هندل ایچیموکو - تنظیم اندازه
   ArrayResize(g_kensei_atr_handles, kensei_count);  // resize آرایه هندل ATR - تنظیم اندازه
   for (int i = 0; i < kensei_count; i++)  // لوپ بر نمادهای Kensei - foreach
   {
      g_kensei_ichi_handles[i] = iIchimoku(kensei_syms[i], Inp_Kensei_Timeframe, Inp_Kensei_Tenkan, Inp_Kensei_Kijun, Inp_Kensei_SenkouB);  // ایجاد هندل ایچیموکو - build handle
      g_kensei_atr_handles[i] = iATR(kensei_syms[i], Inp_Kensei_Timeframe, Inp_Kensei_ATR_Period);  // ایجاد هندل ATR - build handle
      if (g_kensei_ichi_handles[i] == INVALID_HANDLE || g_kensei_atr_handles[i] == INVALID_HANDLE)  // چک هندل‌های معتبر - validate
      {
         LogError("خطا در ایجاد هندل Kensei برای نماد: " + kensei_syms[i]);  // لاگ خطا - ثبت شکست
         return INIT_FAILED;  // بازگشت شکست ابتدایی - fail init
      }
   }
   // مقداردهی اولیه هندل‌های Hoplite - ایجاد هندل‌ها یک بار
   ArrayResize(g_hoplite_bb_handles, hoplite_count);  // resize آرایه هندل BB - تنظیم اندازه
   ArrayResize(g_hoplite_rsi_handles, hoplite_count);  // resize آرایه هندل RSI - تنظیم اندازه
   ArrayResize(g_hoplite_adx_handles, hoplite_count);  // resize آرایه هندل ADX - تنظیم اندازه
   ArrayResize(g_hoplite_atr_handles, hoplite_count);  // resize آرایه هندل ATR - تنظیم اندازه
   for (int i = 0; i < hoplite_count; i++)  // لوپ بر نمادهای Hoplite - foreach
   {
      g_hoplite_bb_handles[i] = iBands(hoplite_syms[i], Inp_Hoplite_Timeframe, Inp_Hoplite_BB_Period, 0, Inp_Hoplite_BB_Deviation, PRICE_CLOSE);  // ایجاد هندل BB - build handle
      g_hoplite_rsi_handles[i] = iRSI(hoplite_syms[i], Inp_Hoplite_Timeframe, Inp_Hoplite_RSI_Period, PRICE_CLOSE);  // ایجاد هندل RSI - build handle
      g_hoplite_adx_handles[i] = iADX(hoplite_syms[i], Inp_Hoplite_Timeframe, Inp_Hoplite_ADX_Period);  // ایجاد هندل ADX - build handle
      g_hoplite_atr_handles[i] = iATR(hoplite_syms[i], Inp_Hoplite_Timeframe, 14);  // ایجاد هندل ATR - build handle (دوره 14 ثابت)
      if (g_hoplite_bb_handles[i] == INVALID_HANDLE || g_hoplite_rsi_handles[i] == INVALID_HANDLE || g_hoplite_adx_handles[i] == INVALID_HANDLE || g_hoplite_atr_handles[i] == INVALID_HANDLE)  // چک هندل‌های معتبر - validate
      {
         LogError("خطا در ایجاد هندل Hoplite برای نماد: " + hoplite_syms[i]);  // لاگ خطا - ثبت شکست
         return INIT_FAILED;  // بازگشت شکست ابتدایی - fail init
      }
   }
   if (Inp_Show_Kensei_Indicators)  // اگر نمایش اندیکاتور Kensei فعال - چک ورودی
   {
      iIchimoku(_Symbol, Inp_Kensei_Timeframe, Inp_Kensei_Tenkan, Inp_Kensei_Kijun, Inp_Kensei_SenkouB);  // نمایش ایچیموکو روی چارت - add to chart
      Log("اندیکاتورهای Kensei نمایش داده شد");  // لاگ نمایش - ثبت
   }
   if (Inp_Show_Hoplite_Indicators)  // اگر نمایش اندیکاتور Hoplite فعال - چک ورودی
   {
      iBands(_Symbol, Inp_Hoplite_Timeframe, Inp_Hoplite_BB_Period, 0, Inp_Hoplite_BB_Deviation, PRICE_CLOSE);  // نمایش BB روی چارت - add to chart
      iRSI(_Symbol, Inp_Hoplite_Timeframe, Inp_Hoplite_RSI_Period, PRICE_CLOSE);  // نمایش RSI روی چارت - add to chart
      iADX(_Symbol, Inp_Hoplite_Timeframe, Inp_Hoplite_ADX_Period);  // نمایش ADX روی چارت - add to chart
      Log("اندیکاتورهای Hoplite نمایش داده شد");  // لاگ نمایش - ثبت
   }
   if (Inp_Show_OnChart_Display)  // اگر نمایش پنل فعال - چک ورودی
   {
      Log("پنل اطلاعاتی روی چارت نمایش داده شد");  // لاگ نمایش پنل - ثبت (پیاده‌سازی پنل فرض شده)
   }
   g_peak_equity = AccountInfoDouble(ACCOUNT_EQUITY);  // مقداردهی اولیه اوج اکویتی - set initial peak
   Log("اوج اکویتی اولیه تنظیم شد: " + DoubleToString(g_peak_equity, 2));  // لاگ تنظیم اولیه - ثبت peak
   EventSetTimer(1);  // تنظیم تایمر هر 1 ثانیه برای چک - timer setup
   return(INIT_SUCCEEDED);  // موفقیت ابتدایی - return success
}

// تابع پایان - OnDeinit - پایان‌دهی EA
void OnDeinit(const int reason)
{
   Log("پایان اکسپرت Chimera V2.0 با دلیل: " + IntegerToString(reason));  // لاگ پایان اکسپرت - ثبت دلیل
   EventKillTimer();  // خاموش کردن تایمر - kill timer
   // آزاد کردن هندل‌های Kensei - release handles
   for (int i = 0; i < ArraySize(g_kensei_ichi_handles); i++)  // لوپ بر هندل‌ها - foreach
   {
      if (g_kensei_ichi_handles[i] != INVALID_HANDLE) IndicatorRelease(g_kensei_ichi_handles[i]);  // آزاد کردن هندل ایچیموکو - release
      if (g_kensei_atr_handles[i] != INVALID_HANDLE) IndicatorRelease(g_kensei_atr_handles[i]);  // آزاد کردن هندل ATR - release
   }
   // آزاد کردن هندل‌های Hoplite - release handles
   for (int i = 0; i < ArraySize(g_hoplite_bb_handles); i++)  // لوپ بر هندل‌ها - foreach
   {
      if (g_hoplite_bb_handles[i] != INVALID_HANDLE) IndicatorRelease(g_hoplite_bb_handles[i]);  // آزاد کردن هندل BB - release
      if (g_hoplite_rsi_handles[i] != INVALID_HANDLE) IndicatorRelease(g_hoplite_rsi_handles[i]);  // آزاد کردن هندل RSI - release
      if (g_hoplite_adx_handles[i] != INVALID_HANDLE) IndicatorRelease(g_hoplite_adx_handles[i]);  // آزاد کردن هندل ADX - release
      if (g_hoplite_atr_handles[i] != INVALID_HANDLE) IndicatorRelease(g_hoplite_atr_handles[i]);  // آزاد کردن هندل ATR - release
   }
   LogDeinit();  // فراخوانی پایان لاگ (بستن فایل) - close log file
}

// تابع تایمر (هر 1 ثانیه) - OnTimer - چک دوره‌ای
void OnTimer()
{
   Log("چک تایمر - بررسی وضعیت پورتفولیو و سیگنال‌ها");  // لاگ هر فراخوانی تایمر - ثبت چک
   if (IsPortfolioDrawdownExceeded())  // چک DD بیش از حد - call function
   {
      Log("افت سرمایه بیش از حد - بستن تمام موقعیت‌ها");  // لاگ DD بیش از حد - ثبت هشدار
      CloseAllPositions();  // بستن همه موقعیت‌ها - call close all
      return;  // خروج از تابع - early return
   }
   if (Inp_Kensei_IsActive)  // اگر Kensei فعال - چک فعال بودن
   {
      for (int i = 0; i < ArraySize(kensei_syms); i++)  // لوپ بر نمادهای Kensei - foreach symbol
      {
         datetime current_time = iTime(kensei_syms[i], Inp_Kensei_Timeframe, 0);  // زمان کندل فعلی برای نماد - get time
         if (current_time > last_kensei_times[i])  // اگر بار جدید تشکیل شده - چک new bar
         {
            Log("بار جدید در تایم‌فریم Kensei برای نماد " + kensei_syms[i]);  // لاگ بار جدید - ثبت new bar
            last_kensei_times[i] = current_time;  // به‌روزرسانی زمان آخرین - update time
            SIGNAL sig = GetKenseiSignal(kensei_syms[i], g_kensei_ichi_handles[i], g_kensei_atr_handles[i]);  // دریافت سیگنال با هندل‌ها - call signal with handles
            OpenTrade(kensei_syms[i], sig, 1, g_kensei_atr_handles[i]);  // باز کردن معامله اگر سیگنال، با هندل ATR - open if signal
         }
      }
   }
   if (Inp_Hoplite_IsActive)  // اگر Hoplite فعال - چک فعال بودن
   {
      for (int i = 0; i < ArraySize(hoplite_syms); i++)  // لوپ بر نمادهای Hoplite - foreach symbol
      {
         datetime current_time = iTime(hoplite_syms[i], Inp_Hoplite_Timeframe, 0);  // زمان کندل فعلی برای نماد - get time
         if (current_time > last_hoplite_times[i])  // اگر بار جدید تشکیل شده - چک new bar
         {
            Log("بار جدید در تایم‌فریم Hoplite برای نماد " + hoplite_syms[i]);  // لاگ بار جدید - ثبت new bar
            last_hoplite_times[i] = current_time;  // به‌روزرسانی زمان آخرین - update time
            SIGNAL sig = GetHopliteSignal(hoplite_syms[i], g_hoplite_bb_handles[i], g_hoplite_rsi_handles[i], g_hoplite_adx_handles[i]);  // دریافت سیگنال با هندل‌ها - call signal with handles
            OpenTrade(hoplite_syms[i], sig, 2, g_hoplite_atr_handles[i]);  // باز کردن معامله اگر سیگنال، با هندل ATR - open if signal
         }
      }
   }
   ManageTrades();  // فراخوانی مدیریت معاملات - manage existing trades
}

// تابع مدیریت معاملات - مدیریت معاملات باز
void ManageTrades()
{
   Log("شروع مدیریت معاملات موجود");  // لاگ شروع مدیریت - ثبت شروع
   for (int i = OrdersTotal() - 1; i >= 0; i--)  // لوپ بر تمام معاملات باز - reverse loop برای ایمنی
   {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))  // انتخاب معامله بر اساس موقعیت - select order
      {
         ulong magic = OrderMagicNumber();  // مجیک نامبر معامله - get magic
         string symbol = OrderSymbol();  // نماد معامله - get symbol
         if (magic == Inp_BaseMagicNumber + 1)  // اگر مجیک Kensei - چک Kensei
         {
            int sym_index = -1;  // ایندکس نماد - initial -1
            for (int j = 0; j < ArraySize(kensei_syms); j++)  // لوپ برای پیدا کردن ایندکس نماد - find index
            {
               if (kensei_syms[j] == symbol) { sym_index = j; break; }  // اگر یافت شد، تنظیم ایندکس - found
            }
            if (sym_index != -1)  // اگر ایندکس یافت شد - چک found
            {
               ManageKenseiExit(OrderTicket(), g_kensei_ichi_handles[sym_index]);  // مدیریت خروج برای Kensei با هندل - call with handle
            }
            else
            {
               LogError("نماد " + symbol + " در لیست Kensei یافت نشد برای تیکت " + IntegerToString(OrderTicket()));  // لاگ خطا نماد یافت نشد - ثبت error
            }
         }
         else if (magic == Inp_BaseMagicNumber + 2)  // اگر مجیک Hoplite - چک Hoplite
         {
            int sym_index = -1;  // ایندکس نماد - initial -1
            for (int j = 0; j < ArraySize(hoplite_syms); j++)  // لوپ برای پیدا کردن ایندکس نماد - find index
            {
               if (hoplite_syms[j] == symbol) { sym_index = j; break; }  // اگر یافت شد، تنظیم ایندکس - found
            }
            if (sym_index != -1)  // اگر ایندکس یافت شد - چک found
            {
               ManageHopliteExit(OrderTicket(), g_hoplite_bb_handles[sym_index]);  // مدیریت خروج برای Hoplite با هندل - call with handle
            }
            else
            {
               LogError("نماد " + symbol + " در لیست Hoplite یافت نشد برای تیکت " + IntegerToString(OrderTicket()));  // لاگ خطا نماد یافت نشد - ثبت error
            }
         }
      }
      else
      {
         LogError("خطا در انتخاب معامله در موقعیت " + IntegerToString(i));  // لاگ خطا در انتخاب - ثبت خطا
      }
   }
   Log("پایان مدیریت معاملات");  // لاگ پایان مدیریت - ثبت پایان
}

// تابع بستن تمام موقعیت‌ها - close all positions
void CloseAllPositions()
{
   Log("شروع بستن تمام موقعیت‌ها");  // لاگ شروع بستن - ثبت شروع
   for (int i = OrdersTotal() - 1; i >= 0; i--)  // لوپ بر تمام معاملات - reverse loop برای ایمنی
   {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))  // انتخاب معامله - select
      {
         int type = OrderType();  // نوع معامله - get type
         double close_price = (type == OP_BUY) ? SymbolInfoDouble(OrderSymbol(), SYMBOL_BID) : SymbolInfoDouble(OrderSymbol(), SYMBOL_ASK);  // قیمت بستن - get close price
         if (OrderClose(OrderTicket(), OrderLots(), close_price, 3, clrRed))
            LogCloseTrade(OrderTicket(), "افت سرمایه بیش از حد");  // لاگ بستن موفق - ثبت موفقیت
         else
            LogError("خطا در بستن معامله تیکت " + IntegerToString(OrderTicket()) + ": " + IntegerToString(GetLastError()));  // لاگ خطا در بستن - ثبت خطا
      }
      else
      {
         LogError("خطا در انتخاب معامله برای بستن در موقعیت " + IntegerToString(i));  // لاگ خطا در انتخاب - ثبت خطا
      }
   }
   Log("پایان بستن موقعیت‌ها");  // لاگ پایان بستن - ثبت پایان
}
