// Logging.mqh
// نسخه بازنویسی شده توسط سقراط (Socrates) - سیستم لاگینگ بهینه و حرفه‌ای
// این سیستم از یک بافر در حافظه برای جمع‌آوری لاگ‌ها استفاده می‌کند و به صورت دسته‌ای (Batch) روی فایل می‌نویسد
// تا از عملیات مکرر و کند I/O جلوگیری شود و عملکرد اکسپرت به حداکثر برسد.

#ifndef LOGGING_MQH
#define LOGGING_MQH

#include "Settings.mqh" // فقط برای دسترسی به Inp_EnableLogging

// --- متغیرهای سراسری برای سیستم لاگ ---
string   g_log_buffer = "";             // بافر اصلی برای نگهداری پیام‌های لاگ در حافظه RAM
string   LogFileName = "ChimeraV2_Log.txt"; // نام فایل لاگ
int      g_log_handle = INVALID_HANDLE;     // هندل فایل برای عملیات نوشتن
datetime g_last_flush_time = 0;             // زمان آخرین ذخیره‌سازی روی فایل برای کنترل بازه‌های زمانی

// --- توابع اصلی سیستم لاگ ---

// تابع جدید برای نوشتن بافر روی فایل
void FlushLogBuffer()
{
   // اگر لاگ غیرفعال است یا بافر خالی است یا هندل فایل نامعتبر است، کاری انجام نده
   if(!Inp_EnableLogging || g_log_handle == INVALID_HANDLE || g_log_buffer == "")
      return;

   // نوشتن کل محتویات بافر در انتهای فایل
   FileSeek(g_log_handle, 0, SEEK_END);
   FileWriteString(g_log_handle, g_log_buffer);
   FileFlush(g_log_handle); // اطمینان از نوشته شدن فوری روی دیسک

   g_log_buffer = ""; // خالی کردن بافر پس از نوشتن
   g_last_flush_time = TimeCurrent(); // ثبت زمان ذخیره‌سازی
   // Print("بافر لاگ روی فایل ذخیره شد."); // این خط برای دیباگ خود سیستم لاگ است، می‌توانید فعالش کنید
}

// تابع راه‌اندازی اولیه سیستم لاگ
void LogInit()
{
   if (!Inp_EnableLogging) return;
   g_log_handle = FileOpen(LogFileName, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if (g_log_handle == INVALID_HANDLE)
   {
      Print("خطای حیاتی: فایل لاگ باز نشد. کد خطا: " + (string)GetLastError());
   }
   else
   {
      // فقط یک بار در شروع، یک پیام مهم برای جدا کردن لاگ‌های هر اجرا می‌نویسیم
      string start_message = "\r\n======================================================\r\n";
      start_message += "سیستم لاگ Chimera V2.0 در تاریخ " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + " راه‌اندازی شد.\r\n";
      start_message += "======================================================\r\n";
      FileWriteString(g_log_handle, start_message);
      FileFlush(g_log_handle);
      g_last_flush_time = TimeCurrent();
   }
}

// تابع پایان کار سیستم لاگ
void LogDeinit()
{
   if(!Inp_EnableLogging || g_log_handle == INVALID_HANDLE) return;
   
   Log("سیستم در حال توقف است. ذخیره نهایی لاگ‌ها...");
   FlushLogBuffer(); // مهم: قبل از بستن فایل، آخرین پیام‌های بافر را ذخیره می‌کنیم
   FileClose(g_log_handle);
   g_log_handle = INVALID_HANDLE;
}

// تابع اصلی برای اضافه کردن پیام به بافر لاگ
void Log(string message, bool is_error = false)
{
   if (!Inp_EnableLogging) return;
   
   // فقط رویدادهای مهم و خطاها لاگ می‌شوند
   string prefix = is_error ? "[خطا]: " : "[اطلاع]: ";
   string full_message = TimeToString(TimeCurrent(), TIME_SECONDS) + " - " + prefix + message + "\r\n";

   // به جای نوشتن مستقیم روی فایل، به بافر اضافه می‌کنیم
   g_log_buffer += full_message;

   // اگر حجم بافر خیلی زیاد شد یا خطایی رخ داد، فوراً ذخیره کن
   if(StringLen(g_log_buffer) > 2048 || is_error) // 2KB buffer
   {
      FlushLogBuffer();
   }
}

// --- توابع کمکی برای لاگ‌های استاندارد ---
// این توابع تغییری نکرده‌اند و از همان تابع Log اصلی استفاده می‌کنند.

void LogSignal(string symbol, string engine, string signal_type)
{
   Log("سیگنال جدید در نماد " + symbol + " از موتور " + engine + ": " + signal_type);
}

void LogOpenTrade(string symbol, string direction, double lots, double sl, double tp)
{
   string msg = "باز کردن معامله در " + symbol + " - جهت: " + direction + ", حجم: " + DoubleToString(lots, 2) + ", SL: " + DoubleToString(sl, _Digits) + ", TP: " + DoubleToString(tp, _Digits);
   Log(msg);
}

void LogCloseTrade(ulong ticket, string reason)
{
   string msg = "بستن معامله با تیکت " + (string)ticket + " به دلیل: " + reason;
   Log(msg);
}

void LogDrawdown(double dd)
{
   string msg = "افت سرمایه فعلی پورتفولیو: " + DoubleToString(dd * 100, 2) + "%";
   // این لاگ می‌تواند خیلی پرتکرار باشد، پس یک شرط برای جلوگیری از اسپم اضافه می‌کنیم
   static double last_logged_dd = 0;
   // فقط اگر افت سرمایه بیش از ۰.۵٪ تغییر کرده باشد لاگ کن
   if(MathAbs(dd - last_logged_dd) > 0.005)
   {
      Log(msg);
      last_logged_dd = dd;
   }
}

void LogError(string error_msg)
{
   Log(error_msg, true);
}


#endif // LOGGING_MQH
