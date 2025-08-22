// Logging.mqh
// سیستم لاگ پیشرفته برای ثبت تمام رویدادهای مهم به زبان فارسی - این فایل سیستم لاگینگ را مدیریت می‌کند

#ifndef LOGGING_MQH  // بررسی برای جلوگیری از تعریف مجدد هدر - جلوگیری از کامپایل چندباره
#define LOGGING_MQH  // تعریف گارد برای جلوگیری از تعریف مجدد

#include <Settings.mqh>  // شامل کردن تنظیمات برای دسترسی به پارامترها اگر لازم - دسترسی به Inp_EnableLogging

// متغیرهای جهانی برای لاگینگ - متغیرهای مورد نیاز برای سیستم لاگ
string LogFileName = "ChimeraV2_Log.txt";  // نام فایل لاگ (در فولدر Files متاتریدر) - نام فایل ذخیره لاگ
int    g_log_handle = INVALID_HANDLE; // متغیر سراسری برای نگهداری هندل فایل - هندل فایل لاگ

// تابع برای باز کردن فایل لاگ در ابتدای برنامه - ابتدایی‌سازی فایل لاگ
void LogInit()
{
   if (!Inp_EnableLogging) return;  // اگر لاگ غیرفعال است، خارج شو - چک فعال بودن لاگ
   g_log_handle = FileOpen(LogFileName, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);  // باز کردن فایل برای نوشتن - باز کردن فایل با فلگ‌های مناسب
   if (g_log_handle == INVALID_HANDLE)  // بررسی موفق بودن باز کردن فایل - چک هندل معتبر
   {
      Print("خطای حیاتی: فایل لاگ باز نشد. کد خطا: " + IntegerToString(GetLastError()));  // چاپ خطا در ژورنال - لاگ خطا در باز کردن
   }
   else
   {
      Print("فایل لاگ با موفقیت باز شد.");  // چاپ موفقیت در ژورنال - لاگ موفقیت باز کردن
   }
}

// تابع برای بستن فایل لاگ در انتهای برنامه - پایان‌دهی فایل لاگ
void LogDeinit()
{
   if (g_log_handle != INVALID_HANDLE)  // اگر هندل معتبر است - چک هندل
   {
      FileClose(g_log_handle);  // بستن فایل - بستن هندل فایل
      g_log_handle = INVALID_HANDLE;  // تنظیم به نامعتبر - ریست هندل
      Print("فایل لاگ با موفقیت بسته شد.");  // چاپ موفقیت در ژورنال - لاگ موفقیت بستن
   }
}

// تابع برای نوشتن لاگ در ژورنال و فایل - تابع اصلی لاگینگ
void Log(string message, bool is_error = false)
{
   if (!Inp_EnableLogging) return;  // اگر لاگ غیرفعال است، خارج شو - چک فعال بودن
   string prefix = is_error ? "خطا: " : "اطلاع: ";  // پیشوند برای تمایز خطا و اطلاع - تعیین پیشوند بر اساس نوع
   string full_message = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + " - " + prefix + message + "\r\n";  // اضافه کردن زمان و خط جدید به پیام - ساخت پیام کامل
   Print(full_message);  // چاپ در ژورنال متاتریدر - خروجی در ترمینال
   if (g_log_handle != INVALID_HANDLE)  // بررسی معتبر بودن هندل - چک هندل فایل
   {
      FileSeek(g_log_handle, 0, SEEK_END);  // رفتن به انتهای فایل - موقعیت‌نویسی در انتها
      FileWriteString(g_log_handle, full_message);  // نوشتن رشته پیام - نوشتن در فایل
      FileFlush(g_log_handle);  // اطمینان از نوشته شدن داده‌ها روی دیسک - فلاش فایل
   }
   else
   {
      Print("خطا در نوشتن لاگ: هندل فایل نامعتبر است.");  // چاپ خطا در ژورنال - لاگ خطا در نوشتن
   }
}

// تابع لاگ برای رویدادهای سیگنال - لاگ سیگنال‌های تولید شده
void LogSignal(string symbol, string engine, string signal_type)
{
   string msg = "سیگنال جدید در نماد " + symbol + " از موتور " + engine + ": " + signal_type;  // ساخت پیام سیگنال - ترکیب strings
   Log(msg);  // ثبت لاگ با استفاده از تابع اصلی - فراخوانی Log
}

// تابع لاگ برای باز کردن معامله - لاگ باز شدن معاملات
void LogOpenTrade(string symbol, string direction, double lots, double sl, double tp)
{
   string msg = "باز کردن معامله در " + symbol + " - جهت: " + direction + ", حجم: " + DoubleToString(lots, 2) + ", SL: " + DoubleToString(sl, _Digits) + ", TP: " + DoubleToString(tp, _Digits);  // ساخت پیام باز کردن معامله - ترکیب جزئیات
   Log(msg);  // ثبت لاگ با استفاده از تابع اصلی - فراخوانی Log
}

// تابع لاگ برای بستن معامله - لاگ بسته شدن معاملات
void LogCloseTrade(ulong ticket, string reason)
{
   string msg = "بستن معامله با تیکت " + IntegerToString(ticket) + " به دلیل: " + reason;  // ساخت پیام بستن معامله - ترکیب تیکت و دلیل
   Log(msg);  // ثبت لاگ با استفاده از تابع اصلی - فراخوانی Log
}

// تابع لاگ برای افت سرمایه - لاگ DD فعلی
void LogDrawdown(double dd)
{
   string msg = "افت سرمایه فعلی پورتفولیو: " + DoubleToString(dd * 100, 2) + "%";  // ساخت پیام افت سرمایه - تبدیل به درصد
   Log(msg);  // ثبت لاگ با استفاده از تابع اصلی - فراخوانی Log
}

// تابع لاگ برای خطاها - لاگ خطاهای خاص
void LogError(string error_msg)
{
   Log(error_msg, true);  // ثبت لاگ خطا با استفاده از تابع اصلی و فلگ خطا - فراخوانی Log با is_error=true
}

#endif  // پایان گارد تعریف - پایان هدر
