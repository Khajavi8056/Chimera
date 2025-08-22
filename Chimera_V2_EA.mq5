// Chimera_V2_EA.mq5
// این فایل اصلی اکسپرت است که نقش رهبر ارکستر را ایفا می‌کند و تمام اجزای سیستم را هماهنگ می‌نماید. تمام موتورها و مدیریت‌ها از اینجا فراخوانی می‌شوند.

#property copyright "Chimera V2.0"  // حقوق کپی‌رایت: نام و نسخه EA برای نمایش در متاتریدر
#property version   "2.00"  // نسخه EA: برای پیگیری تغییرات نسخه
#property strict  // حالت دقیق: فعال کردن بررسی‌های سخت‌گیرانه کامپایلر برای جلوگیری از خطاها

#include "Settings.mqh"  // شامل فایل تنظیمات: دسترسی به تمام ورودی‌ها و ثابت‌ها
#include "Logging.mqh"  // شامل فایل لاگینگ: برای ثبت رویدادها و خطاها
#include "MoneyManagement.mqh"  // شامل فایل مدیریت پول: برای محاسبه حجم و ریسک
#include "Engine_Kensei.mqh"  // شامل موتور Kensei: موتور تهاجمی روندگرا
#include "Engine_Hoplite.mqh"  // شامل موتور Hoplite: موتور دفاعی بازگشت به میانگین

// متغیرهای جهانی شروع می‌شوند - این متغیرها در سراسر EA قابل دسترسی هستند
string kensei_syms[];  // آرایه نمادهای Kensei: لیست نمادهایی که موتور Kensei روی آن‌ها کار می‌کند
datetime last_kensei_times[];  // آرایه زمان آخرین بررسی برای هر نماد Kensei: برای تشخیص بار جدید
string hoplite_syms[];  // آرایه نمادهای Hoplite: لیست نمادهایی که موتور Hoplite روی آن‌ها کار می‌کند
datetime last_hoplite_times[];  // آرایه زمان آخرین بررسی برای هر نماد Hoplite: برای تشخیص بار جدید
double g_peak_equity = 0;  // اوج اکویتی: برای محاسبه حداکثر افت سرمایه (drawdown)

// آرایه‌های هندل اندیکاتورها - هندل‌ها یک بار ساخته می‌شوند تا عملکرد بهینه شود
int g_kensei_ichi_handles[];  // آرایه هندل‌های ایچیموکو برای نمادهای Kensei: ذخیره هندل‌ها برای دسترسی سریع
int g_kensei_atr_handles[];  // آرایه هندل‌های ATR برای نمادهای Kensei: ذخیره هندل‌ها
int g_hoplite_bb_handles[];  // آرایه هندل‌های بولینگر باند برای نمادهای Hoplite: ذخیره هندل‌ها
int g_hoplite_rsi_handles[];  // آرایه هندل‌های RSI برای نمادهای Hoplite: ذخیره هندل‌ها
int g_hoplite_adx_handles[];  // آرایه هندل‌های ADX برای نمادهای Hoplite: ذخیره هندل‌ها
int g_hoplite_atr_handles[];  // آرایه هندل‌های ATR برای نمادهای Hoplite: ذخیره هندل‌ها

// تابع OnInit: این تابع هنگام شروع EA فراخوانی می‌شود و تمام ابتدایی‌سازی‌ها را انجام می‌دهد
int OnInit()  // بازگشت int: INIT_SUCCEEDED برای موفقیت، INIT_FAILED برای شکست
{
   Log("شروع اکسپرت Chimera V2.0");  // ثبت لاگ شروع EA: برای اطلاع از راه‌اندازی موفق
   LogInit();  // فراخوانی تابع ابتدایی‌سازی لاگ: باز کردن فایل لاگ
   int kensei_count = StringSplit(Inp_Kensei_Symbols, ',', kensei_syms);  // تقسیم لیست نمادهای Kensei به آرایه: تعداد نمادها را برمی‌گرداند
   if (kensei_count <= 0) { LogError("خطا در تقسیم نمادهای Kensei: " + Inp_Kensei_Symbols); return INIT_FAILED; }  // چک خطا در تقسیم: اگر شکست، EA را متوقف کن
   ArrayResize(last_kensei_times, kensei_count);  // تغییر اندازه آرایه زمان‌ها به تعداد نمادها: برای ذخیره زمان آخرین چک هر نماد
   ArrayInitialize(last_kensei_times, 0);  // مقداردهی اولیه آرایه زمان‌ها به 0: یعنی هیچ چک قبلی وجود ندارد
   int hoplite_count = StringSplit(Inp_Hoplite_Symbols, ',', hoplite_syms);  // تقسیم لیست نمادهای Hoplite به آرایه: مشابه Kensei
   if (hoplite_count <= 0) { LogError("خطا در تقسیم نمادهای Hoplite: " + Inp_Hoplite_Symbols); return INIT_FAILED; }  // چک خطا در تقسیم Hoplite
   ArrayResize(last_hoplite_times, hoplite_count);  // تغییر اندازه آرایه زمان‌ها برای Hoplite
   ArrayInitialize(last_hoplite_times, 0);  // مقداردهی اولیه به 0
   // ابتدایی‌سازی هندل‌های Kensei شروع می‌شود
   ArrayResize(g_kensei_ichi_handles, kensei_count);  // تغییر اندازه آرایه هندل ایچیموکو به تعداد نمادها
   ArrayResize(g_kensei_atr_handles, kensei_count);  // تغییر اندازه آرایه هندل ATR
   for (int i = 0; i < kensei_count; i++)  // لوپ روی تمام نمادهای Kensei: برای ایجاد هندل هر نماد
   {
      g_kensei_ichi_handles[i] = iIchimoku(kensei_syms[i], Inp_Kensei_Timeframe, Inp_Kensei_Tenkan, Inp_Kensei_Kijun, Inp_Kensei_SenkouB);  // ایجاد هندل ایچیموکو برای نماد فعلی
      g_kensei_atr_handles[i] = iATR(kensei_syms[i], Inp_Kensei_Timeframe, Inp_Kensei_ATR_Period);  // ایجاد هندل ATR برای نماد فعلی
      if (g_kensei_ichi_handles[i] == INVALID_HANDLE || g_kensei_atr_handles[i] == INVALID_HANDLE)  // چک validity هندل‌ها: اگر نامعتبر، خطا
      {
         LogError("خطا در ایجاد هندل Kensei برای نماد: " + kensei_syms[i]);  // ثبت خطا
         return INIT_FAILED;  // بازگشت شکست ابتدایی‌سازی
      }
   }
   // ابتدایی‌سازی هندل‌های Hoplite شروع می‌شود
   ArrayResize(g_hoplite_bb_handles, hoplite_count);  // تغییر اندازه آرایه هندل BB
   ArrayResize(g_hoplite_rsi_handles, hoplite_count);  // تغییر اندازه آرایه هندل RSI
   ArrayResize(g_hoplite_adx_handles, hoplite_count);  // تغییر اندازه آرایه هندل ADX
   ArrayResize(g_hoplite_atr_handles, hoplite_count);  // تغییر اندازه آرایه هندل ATR
   for (int i = 0; i < hoplite_count; i++)  // لوپ روی تمام نمادهای Hoplite
   {
      g_hoplite_bb_handles[i] = iBands(hoplite_syms[i], Inp_Hoplite_Timeframe, Inp_Hoplite_BB_Period, 0, Inp_Hoplite_BB_Deviation, PRICE_CLOSE);  // ایجاد هندل BB
      g_hoplite_rsi_handles[i] = iRSI(hoplite_syms[i], Inp_Hoplite_Timeframe, Inp_Hoplite_RSI_Period, PRICE_CLOSE);  // ایجاد هندل RSI
      g_hoplite_adx_handles[i] = iADX(hoplite_syms[i], Inp_Hoplite_Timeframe, Inp_Hoplite_ADX_Period);  // ایجاد هندل ADX
      g_hoplite_atr_handles[i] = iATR(hoplite_syms[i], Inp_Hoplite_Timeframe, 14);  // ایجاد هندل ATR با دوره ثابت 14
      if (g_hoplite_bb_handles[i] == INVALID_HANDLE || g_hoplite_rsi_handles[i] == INVALID_HANDLE || g_hoplite_adx_handles[i] == INVALID_HANDLE || g_hoplite_atr_handles[i] == INVALID_HANDLE)  // چک validity
      {
         LogError("خطا در ایجاد هندل Hoplite برای نماد: " + hoplite_syms[i]);  // ثبت خطا
         return INIT_FAILED;  // بازگشت شکست
      }
   }
   if (Inp_Show_Kensei_Indicators)  // اگر نمایش اندیکاتورهای Kensei فعال باشد
   {
      iIchimoku(_Symbol, Inp_Kensei_Timeframe, Inp_Kensei_Tenkan, Inp_Kensei_Kijun, Inp_Kensei_SenkouB);  // اضافه کردن ایچیموکو به چارت فعلی
      Log("اندیکاتورهای Kensei نمایش داده شد");  // ثبت لاگ نمایش
   }
   if (Inp_Show_Hoplite_Indicators)  // اگر نمایش اندیکاتورهای Hoplite فعال باشد
   {
      iBands(_Symbol, Inp_Hoplite_Timeframe, Inp_Hoplite_BB_Period, 0, Inp_Hoplite_BB_Deviation, PRICE_CLOSE);  // اضافه کردن BB به چارت
      iRSI(_Symbol, Inp_Hoplite_Timeframe, Inp_Hoplite_RSI_Period, PRICE_CLOSE);  // اضافه کردن RSI به چارت
      iADX(_Symbol, Inp_Hoplite_Timeframe, Inp_Hoplite_ADX_Period);  // اضافه کردن ADX به چارت
      Log("اندیکاتورهای Hoplite نمایش داده شد");  // ثبت لاگ نمایش
   }
   if (Inp_Show_OnChart_Display)  // اگر نمایش پنل روی چارت فعال باشد
   {
      Log("پنل اطلاعاتی روی چارت نمایش داده شد");  // ثبت لاگ (پیاده‌سازی پنل در کد فرض شده است)
   }
   g_peak_equity = AccountInfoDouble(ACCOUNT_EQUITY);  // تنظیم اوج اکویتی اولیه بر اساس اکویتی فعلی حساب
   Log("اوج اکویتی اولیه تنظیم شد: " + DoubleToString(g_peak_equity, 2));  // ثبت لاگ مقدار اولیه
   EventSetTimer(1);  // تنظیم تایمر برای فراخوانی OnTimer هر 1 ثانیه: برای چک دوره‌ای
   return(INIT_SUCCEEDED);  // بازگشت موفقیت ابتدایی‌سازی: EA آماده کار است
}

// تابع OnDeinit: این تابع هنگام توقف EA فراخوانی می‌شود و منابع را آزاد می‌کند
void OnDeinit(const int reason)  // پارامتر reason: دلیل توقف (مثلاً تغییر تنظیمات)
{
   Log("پایان اکسپرت Chimera V2.0 با دلیل: " + IntegerToString(reason));  // ثبت لاگ پایان با دلیل
   EventKillTimer();  // خاموش کردن تایمر: جلوگیری از فراخوانی‌های بیشتر
   // آزاد کردن هندل‌های Kensei شروع می‌شود
   for (int i = 0; i < ArraySize(g_kensei_ichi_handles); i++)  // لوپ روی تمام هندل‌های Kensei
   {
      if (g_kensei_ichi_handles[i] != INVALID_HANDLE) IndicatorRelease(g_kensei_ichi_handles[i]);  // آزاد کردن هندل ایچیموکو اگر معتبر باشد
      if (g_kensei_atr_handles[i] != INVALID_HANDLE) IndicatorRelease(g_kensei_atr_handles[i]);  // آزاد کردن هندل ATR
   }
   // آزاد کردن هندل‌های Hoplite
   for (int i = 0; i < ArraySize(g_hoplite_bb_handles); i++)  // لوپ روی تمام هندل‌های Hoplite
   {
      if (g_hoplite_bb_handles[i] != INVALID_HANDLE) IndicatorRelease(g_hoplite_bb_handles[i]);  // آزاد کردن هندل BB
      if (g_hoplite_rsi_handles[i] != INVALID_HANDLE) IndicatorRelease(g_hoplite_rsi_handles[i]);  // آزاد کردن هندل RSI
      if (g_hoplite_adx_handles[i] != INVALID_HANDLE) IndicatorRelease(g_hoplite_adx_handles[i]);  // آزاد کردن هندل ADX
      if (g_hoplite_atr_handles[i] != INVALID_HANDLE) IndicatorRelease(g_hoplite_atr_handles[i]);  // آزاد کردن هندل ATR
   }
   LogDeinit();  // فراخوانی تابع پایان لاگ: بستن فایل لاگ
}

// تابع OnTimer: این تابع هر 1 ثانیه فراخوانی می‌شود و چک‌های دوره‌ای را انجام می‌دهد
void OnTimer()  // بدون پارامتر و بازگشت void: فقط عملیات چک را انجام می‌دهد
{
   Log("چک تایمر - بررسی وضعیت پورتفولیو و سیگنال‌ها");  // ثبت لاگ هر چک تایمر
   if (IsPortfolioDrawdownExceeded())  // چک اگر افت سرمایه بیش از حد مجاز باشد
   {
      Log("افت سرمایه بیش از حد - بستن تمام موقعیت‌ها");  // ثبت لاگ هشدار
      CloseAllPositions();  // فراخوانی تابع بستن تمام موقعیت‌ها
      return;  // خروج زودرس از تابع: اگر DD بیش از حد، بقیه چک‌ها را انجام نده
   }
   if (Inp_Kensei_IsActive)  // اگر موتور Kensei فعال باشد
   {
      for (int i = 0; i < ArraySize(kensei_syms); i++)  // لوپ روی تمام نمادهای Kensei
      {
         datetime current_time = iTime(kensei_syms[i], Inp_Kensei_Timeframe, 0);  // دریافت زمان کندل فعلی نماد
         if (current_time > last_kensei_times[i])  // چک اگر بار جدید تشکیل شده باشد (زمان جدید > زمان آخرین)
         {
            Log("بار جدید در تایم‌فریم Kensei برای نماد " + kensei_syms[i]);  // ثبت لاگ بار جدید
            last_kensei_times[i] = current_time;  // بروزرسانی زمان آخرین چک
            SIGNAL sig = GetKenseiSignal(kensei_syms[i], g_kensei_ichi_handles[i], g_kensei_atr_handles[i]);  // دریافت سیگنال از موتور Kensei
            OpenTrade(kensei_syms[i], sig, 1, g_kensei_atr_handles[i]);  // باز کردن معامله اگر سیگنال وجود داشته باشد (1 برای ID موتور Kensei)
         }
      }
   }
   if (Inp_Hoplite_IsActive)  // اگر موتور Hoplite فعال باشد
   {
      for (int i = 0; i < ArraySize(hoplite_syms); i++)  // لوپ روی تمام نمادهای Hoplite
      {
         datetime current_time = iTime(hoplite_syms[i], Inp_Hoplite_Timeframe, 0);  // دریافت زمان کندل فعلی
         if (current_time > last_hoplite_times[i])  // چک بار جدید
         {
            Log("بار جدید در تایم‌فریم Hoplite برای نماد " + hoplite_syms[i]);  // ثبت لاگ
            last_hoplite_times[i] = current_time;  // بروزرسانی زمان
            SIGNAL sig = GetHopliteSignal(hoplite_syms[i], g_hoplite_bb_handles[i], g_hoplite_rsi_handles[i], g_hoplite_adx_handles[i]);  // دریافت سیگنال از Hoplite
            OpenTrade(hoplite_syms[i], sig, 2, g_hoplite_atr_handles[i]);  // باز کردن معامله (2 برای ID موتور Hoplite)
         }
      }
   }
   ManageTrades();  // فراخوانی مدیریت معاملات موجود: چک خروج‌ها و بروزرسانی‌ها
}

// تابع ManageTrades: مدیریت معاملات باز، مانند چک شرط خروج
void ManageTrades()  // بدون پارامتر، فقط لوپ روی موقعیت‌ها
{
   Log("شروع مدیریت معاملات موجود");  // ثبت لاگ شروع مدیریت
   for (int i = PositionsTotal() - 1; i >= 0; i--)  // لوپ معکوس روی تمام موقعیت‌ها: از آخر به اول برای ایمنی در بستن
   {
      ulong ticket = PositionGetTicket(i);  // دریافت تیکت موقعیت i
      if (ticket == 0) continue;  // اگر تیکت نامعتبر، رد شو به موقعیت بعدی
      ulong magic = PositionGetInteger(POSITION_MAGIC);  // دریافت مجیک نامبر موقعیت
      string symbol = PositionGetString(POSITION_SYMBOL);  // دریافت نماد موقعیت
      if (magic == Inp_BaseMagicNumber + 1)  // اگر مجیک مربوط به Kensei باشد
      {
         int sym_index = -1;  // ایندکس اولیه -1 (یعنی یافت نشد)
         for (int j = 0; j < ArraySize(kensei_syms); j++)  // لوپ برای پیدا کردن ایندکس نماد در لیست Kensei
         {
            if (kensei_syms[j] == symbol) { sym_index = j; break; }  // اگر یافت شد، ایندکس را تنظیم کن و لوپ را قطع کن
         }
         if (sym_index != -1)  // اگر نماد یافت شد
         {
            ManageKenseiExit(ticket, g_kensei_ichi_handles[sym_index]);  // فراخوانی مدیریت خروج Kensei با تیکت و هندل مربوطه
         }
         else
         {
            LogError("نماد " + symbol + " در لیست Kensei یافت نشد برای تیکت " + IntegerToString(ticket));  // ثبت خطا اگر نماد یافت نشود
         }
      }
      else if (magic == Inp_BaseMagicNumber + 2)  // اگر مجیک مربوط به Hoplite باشد
      {
         int sym_index = -1;  // ایندکس اولیه -1
         for (int j = 0; j < ArraySize(hoplite_syms); j++)  // لوپ برای پیدا کردن ایندکس در لیست Hoplite
         {
            if (hoplite_syms[j] == symbol) { sym_index = j; break; }  // تنظیم ایندکس اگر یافت شد
         }
         if (sym_index != -1)  // اگر یافت شد
         {
            ManageHopliteExit(ticket, g_hoplite_bb_handles[sym_index]);  // فراخوانی مدیریت خروج Hoplite
         }
         else
         {
            LogError("نماد " + symbol + " در لیست Hoplite یافت نشد برای تیکت " + IntegerToString(ticket));  // ثبت خطا
         }
      }
   }
   Log("پایان مدیریت معاملات");  // ثبت لاگ پایان مدیریت
}

// تابع CloseAllPositions: بستن تمام موقعیت‌های باز در موارد اضطراری مانند DD بیش از حد
void CloseAllPositions()  // بدون پارامتر، لوپ روی موقعیت‌ها و بستن آن‌ها
{
   Log("شروع بستن تمام موقعیت‌ها");  // ثبت لاگ شروع
   CTrade trade;  // ایجاد شیء CTrade: برای عملیات معاملاتی مانند بستن
   for (int i = PositionsTotal() - 1; i >= 0; i--)  // لوپ معکوس روی موقعیت‌ها
   {
      ulong ticket = PositionGetTicket(i);  // دریافت تیکت
      if (ticket == 0) continue;  // رد اگر نامعتبر
      string symbol = PositionGetString(POSITION_SYMBOL);  // دریافت نماد
      long type = PositionGetInteger(POSITION_TYPE);  // دریافت نوع موقعیت (خرید یا فروش)
      double close_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);  // تعیین قیمت بستن بر اساس نوع
      if (trade.PositionClose(ticket, 3))  // تلاش برای بستن موقعیت با slippage 3
         LogCloseTrade(ticket, "افت سرمایه بیش از حد");  // ثبت لاگ موفقیت بستن
      else
         LogError("خطا در بستن موقعیت تیکت " + IntegerToString(ticket) + ": " + IntegerToString(trade.ResultRetcode()));  // ثبت خطا با کد بازگشت
   }
   Log("پایان بستن موقعیت‌ها");  // ثبت لاگ پایان
}
