// Logging.mqh
// این فایل سیستم لاگینگ پیشرفته را پیاده‌سازی می‌کند که تمام رویدادها را به زبان فارسی ثبت می‌کند. مفید برای دیباگ و پیگیری.

#ifndef LOGGING_MQH  // جلوگیری از تعریف مجدد
#define LOGGING_MQH  // تعریف گارد

#include "Settings.mqh"  // شامل تنظیمات: مانند Inp_EnableLogging
#include "MoneyManagement.mqh"  // شامل مدیریت پول: وابستگی برای لاگ‌های مرتبط
#include "Engine_Kensei.mqh"  // شامل Kensei: برای لاگ سیگنال‌ها
#include "Engine_Hoplite.mqh"  // شامل Hoplite: مشابه

// متغیرهای جهانی لاگینگ شروع می‌شوند
string LogFileName = "ChimeraV2_Log.txt";  // نام فایل لاگ: در فولدر Files متاتریدر ذخیره می‌شود
int    g_log_handle = INVALID_HANDLE;  // هندل فایل لاگ: INVALID_HANDLE یعنی بسته است

// تابع LogInit: باز کردن فایل لاگ در شروع برنامه
void LogInit()  // بدون پارامتر، فقط چک و باز کردن فایل
{
   if (!Inp_EnableLogging) return;  // اگر لاگ غیرفعال، خروج بدون عملیات
   g_log_handle = FileOpen(LogFileName, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);  // باز کردن فایل با فلگ‌های نوشتن، متن، ANSI و اشتراک‌گذاری
   if (g_log_handle == INVALID_HANDLE)  // اگر باز کردن شکست
   {
      Print("خطای حیاتی: فایل لاگ باز نشد. کد خطا: " + IntegerToString(GetLastError()));  // چاپ خطا در ژورنال متاتریدر
   }
   else
   {
      Print("فایل لاگ با موفقیت باز شد.");  // چاپ موفقیت
   }
}

// تابع LogDeinit: بستن فایل لاگ در پایان برنامه
void LogDeinit()  // بدون پارامتر، چک و بستن
{
   if (g_log_handle != INVALID_HANDLE)  // اگر فایل باز است
   {
      FileClose(g_log_handle);  // بستن فایل
      g_log_handle = INVALID_HANDLE;  // تنظیم به نامعتبر برای جلوگیری از استفاده مجدد
      Print("فایل لاگ با موفقیت بسته شد.");  // چاپ موفقیت
   }
}

// تابع Log: نوشتن پیام در ژورنال و فایل - تابع اصلی لاگینگ
void Log(string message, bool is_error = false)  // پارامترها: پیام و فلگ خطا (پیش‌فرض false)
{
   if (!Inp_EnableLogging) return;  // اگر غیرفعال، خروج
   string prefix = is_error ? "خطا: " : "اطلاع: ";  // تعیین پیشوند بر اساس فلگ: برای تمایز خطا و اطلاع
   string full_message = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + " - " + prefix + message + "\r\n";  // ساخت پیام کامل با زمان و خط جدید
   Print(full_message);  // چاپ در ژورنال متاتریدر
   if (g_log_handle != INVALID_HANDLE)  // اگر فایل باز است
   {
      FileSeek(g_log_handle, 0, SEEK_END);  // رفتن به انتهای فایل برای اضافه کردن
      FileWriteString(g_log_handle, full_message);  // نوشتن پیام
      FileFlush(g_log_handle);  // فلاش برای اطمینان از ذخیره روی دیسک
   }
   else
   {
      Print("خطا در نوشتن لاگ: هندل فایل نامعتبر است.");  // چاپ خطا اگر فایل بسته باشد
   }
}

// تابع LogSignal: لاگ سیگنال‌های تولید شده - wrapper برای Log
void LogSignal(string symbol, string engine, string signal_type)  // پارامترها: نماد، موتور و نوع سیگنال
{
   string msg = "سیگنال جدید در نماد " + symbol + " از موتور " + engine + ": " + signal_type;  // ساخت پیام سیگنال
   Log(msg);  // فراخوانی Log با پیام ساخته‌شده
}

// تابع LogOpenTrade: لاگ باز شدن معاملات
void LogOpenTrade(string symbol, string direction, double lots, double sl, double tp)  // پارامترها: جزئیات معامله
{
   string msg = "باز کردن معامله در " + symbol + " - جهت: " + direction + ", حجم: " + DoubleToString(lots, 2) + ", SL: " + DoubleToString(sl, _Digits) + ", TP: " + DoubleToString(tp, _Digits);  // ساخت پیام
   Log(msg);  // فراخوانی Log
}

// تابع LogCloseTrade: لاگ بسته شدن معاملات
void LogCloseTrade(ulong ticket, string reason)  // پارامترها: تیکت و دلیل
{
   string msg = "بستن معامله با تیکت " + IntegerToString(ticket) + " به دلیل: " + reason;  // ساخت پیام
   Log(msg);  // فراخوانی Log
}

// تابع LogDrawdown: لاگ افت سرمایه فعلی
void LogDrawdown(double dd)  // پارامتر: مقدار DD
{
   string msg = "افت سرمایه فعلی پورتفولیو: " + DoubleToString(dd * 100, 2) + "%";  // ساخت پیام با تبدیل به درصد
   Log(msg);  // فراخوانی Log
}

// تابع LogError: لاگ خطاها - wrapper با فلگ خطا
void LogError(string error_msg)  // پارامتر: پیام خطا
{
   Log(error_msg, true);  // فراخوانی Log با is_error=true
}

#endif  // پایان گارد
