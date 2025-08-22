// Logging.mqh
// سیستم لاگینگ پیشرفته به زبان فارسی برای ثبت رویدادها، خطاها و سیگنال‌ها.
// این سیستم فایل می‌نویسد و پرینت می‌کند برای دیباگینگ زنده.
// وابستگی‌ها حداقل: فقط Settings برای Inp_EnableLogging.
// کامنت‌ها برای آموزش: توضیح هر خط.

// جلوگیری از تکرار
#ifndef LOGGING_MQH
#define LOGGING_MQH

#include "Settings.mqh" // فقط برای Inp_EnableLogging

string LogFileName = "ChimeraV2_Log.txt"; // نام فایل لاگ - در فولدر MQL5/Files
int g_log_handle = INVALID_HANDLE; // هندل فایل - جهانی برای دسترسی

// LogInit: باز کردن فایل در ابتدایی
void LogInit()
{
   if (!Inp_EnableLogging) return; // اگر غیرفعال، بازگشت بدون عملیات
   g_log_handle = FileOpen(LogFileName, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE); // باز کردن با فلگ‌ها برای نوشتن و اشتراک
   if (g_log_handle == INVALID_HANDLE) // چک شکست
   {
      Print("خطای حیاتی: فایل لاگ باز نشد. کد خطا: " + IntegerToString(GetLastError())); // پرینت خطا در ترمینال
   }
   else
   {
      Print("فایل لاگ با موفقیت باز شد."); // پرینت موفق
   }
}

// LogDeinit: بستن فایل در پایان
void LogDeinit()
{
   if (g_log_handle != INVALID_HANDLE) // اگر باز است
   {
      FileClose(g_log_handle); // بستن
      g_log_handle = INVALID_HANDLE; // تنظیم به نامعتبر
      Print("فایل لاگ با موفقیت بسته شد."); // پرینت
   }
}

// Log: نوشتن پیام عمومی - با پیشوند اطلاع یا خطا
void Log(string message, bool is_error = false)
{
   if (!Inp_EnableLogging) return; // چک فعال بودن
   string prefix = is_error ? "خطا: " : "اطلاع: "; // انتخاب پیشوند
   string full_message = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + " - " + prefix + message + "\r\n"; // ساخت پیام کامل با زمان
   Print(full_message); // پرینت در ترمینال
   if (g_log_handle != INVALID_HANDLE) // اگر فایل باز
   {
      FileSeek(g_log_handle, 0, SEEK_END); // رفتن به انتها
      FileWriteString(g_log_handle, full_message); // نوشتن
      FileFlush(g_log_handle); // فلاش برای ذخیره فوری
   }
   else
   {
      Print("خطا در نوشتن لاگ: هندل فایل نامعتبر است."); // پرینت خطا
   }
}

// LogSignal: لاگ سیگنال خاص
void LogSignal(string symbol, string engine, string signal_type)
{
   string msg = "سیگنال جدید در نماد " + symbol + " از موتور " + engine + ": " + signal_type; // ساخت پیام
   Log(msg); // نوشتن با تابع عمومی
}

// LogOpenTrade: لاگ باز کردن معامله
void LogOpenTrade(string symbol, string direction, double lots, double sl, double tp)
{
   string msg = "باز کردن معامله در " + symbol + " - جهت: " + direction + ", حجم: " + DoubleToString(lots, 2) + ", SL: " + DoubleToString(sl, _Digits) + ", TP: " + DoubleToString(tp, _Digits);
   Log(msg);
}

// LogCloseTrade: لاگ بستن
void LogCloseTrade(ulong ticket, string reason)
{
   string msg = "بستن معامله با تیکت " + IntegerToString(ticket) + " به دلیل: " + reason;
   Log(msg);
}

// LogDrawdown: لاگ افت سرمایه
void LogDrawdown(double dd)
{
   string msg = "افت سرمایه فعلی پورتفولیو: " + DoubleToString(dd * 100, 2) + "%";
   Log(msg);
}

// LogError: لاگ خطا - با فلگ true
void LogError(string error_msg)
{
   Log(error_msg, true);
}

// پایان
#endif
