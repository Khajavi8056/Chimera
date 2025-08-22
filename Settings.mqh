// Settings.mqh
// این فایل به عنوان پنل کنترل مرکزی عمل می‌کند و تمام پارامترهای ورودی کاربر و ثابت‌های سیستم را تعریف می‌کند. این فایل برای جلوگیری از پراکندگی تنظیمات در کدهای دیگر استفاده می‌شود.

// جلوگیری از تعریف مجدد هدر فایل برای جلوگیری از خطاهای کامپایل چندباره
#ifndef SETTINGS_MQH  // اگر SETTINGS_MQH قبلاً تعریف نشده باشد
#define SETTINGS_MQH  // تعریف SETTINGS_MQH برای علامت‌گذاری اینکه این هدر قبلاً شامل شده است

// تعریف enum برای انواع منطق خروج معاملات، که به کاربر اجازه انتخاب بین خروج دینامیک یا مبتنی بر نسبت ریسک به ریوارد را می‌دهد
enum ENUM_EXIT_LOGIC  // تعریف یک نوع شمارش‌شده (enum) برای منطق خروج
{
   EXIT_DYNAMIC,    // خروج دینامیک: بر اساس اندیکاتورها مانند کیجون-سن یا خط میانی بولینگر - مناسب برای بازارهای پویا
   EXIT_RRR         // خروج مبتنی بر نسبت ریسک به ریوارد ثابت: خروج وقتی سود به نسبت مشخصی از ریسک برسد - مناسب برای استراتژی‌های ثابت
};

// تعریف enum برای انواع سیگنال‌ها، که نشان‌دهنده هیچ سیگنال، سیگنال خرید یا فروش است - این enum در موتورهای معاملاتی استفاده می‌شود
enum SIGNAL { SIGNAL_NONE, SIGNAL_LONG, SIGNAL_SHORT };  // SIGNAL_NONE: بدون سیگنال، SIGNAL_LONG: سیگنال خرید، SIGNAL_SHORT: سیگنال فروش

// بخش پارامترهای ورودی کاربر شروع می‌شود - این ورودی‌ها در پنل تنظیمات EA در متاتریدر قابل تغییر هستند
input double Inp_TotalInitialCapital = 10000.0; // سرمایه اولیه مجازی: برای محاسبه حجم معاملات و درصد افت سرمایه استفاده می‌شود - این مقدار برای شبیه‌سازی ریسک بدون تأثیر بر حساب واقعی است
input double Inp_Kensei_Weight = 0.60; // وزن تخصیص سرمایه به موتور Kensei: بین 0.0 تا 1.0 - درصد سرمایه اختصاصی به موتور تهاجمی Kensei
input double Inp_Hoplite_Weight = 0.40; // وزن تخصیص سرمایه به موتور Hoplite: بین 0.0 تا 1.0 - درصد سرمایه اختصاصی به موتور دفاعی Hoplite
input double Inp_MaxPortfolioDrawdown = 0.09; // حداکثر افت سرمایه مجاز برای کل پورتفولیو: به صورت درصد (مثلاً 0.09 یعنی 9%) - اگر افت بیشتر شود، تمام معاملات بسته می‌شوند
input ulong  Inp_BaseMagicNumber = 12345; // شماره مجیک پایه: برای تمایز معاملات این EA از سایر EAها - مجیک نامبر منحصر به فرد برای شناسایی معاملات

input string Inp_Kensei_Symbols = "EURUSD,GBPUSD,XAUUSD"; // لیست نمادهای معاملاتی برای موتور Kensei: جدا شده با کاما - نمادهایی که Kensei روی آن‌ها معامله می‌کند
input bool   Inp_Kensei_IsActive = true; // فعال‌سازی موتور Kensei: true برای فعال، false برای غیرفعال - کلید اصلی برای روشن/خاموش کردن موتور تهاجمی
input ENUM_TIMEFRAMES Inp_Kensei_Timeframe = PERIOD_H1; // تایم‌فریم عملیاتی برای Kensei: مثلاً PERIOD_H1 برای ساعتی - تایم‌فریم محاسبات اندیکاتورها
input int    Inp_Kensei_Tenkan = 9; // دوره تنکان-سن در ایچیموکو: معمولاً 9 - برای محاسبه خط تنکان-سن
input int    Inp_Kensei_Kijun = 26; // دوره کیجون-سن در ایچیموکو: معمولاً 26 - برای محاسبه خط کیجون-سن
input int    Inp_Kensei_SenkouB = 52; // دوره سنکو اسپن B در ایچیموکو: معمولاً 52 - برای محاسبه ابر کومو
input int    Inp_Kensei_ATR_Period = 14; // دوره ATR برای حد ضرر در Kensei: معمولاً 14 - برای محاسبه نوسان بازار
input double Inp_Kensei_ATR_Multiplier = 3.0; // ضریب ATR برای فاصله حد ضرر: مثلاً 3.0 - تنظیم حساسیت حد ضرر
input int    Inp_Kensei_Chikou_OpenSpace = 12; // تعداد کندل‌های گذشته برای چک فضای باز چیکو: مثلاً 12 - برای شرط ورود معامله

input string Inp_Hoplite_Symbols = "EURUSD,GBPUSD,XAUUSD"; // لیست نمادهای معاملاتی برای موتور Hoplite: جدا شده با کاما - نمادهایی که Hoplite روی آن‌ها معامله می‌کند
input bool   Inp_Hoplite_IsActive = true; // فعال‌سازی موتور Hoplite: true برای فعال، false برای غیرفعال - کلید اصلی برای روشن/خاموش کردن موتور دفاعی
input ENUM_TIMEFRAMES Inp_Hoplite_Timeframe = PERIOD_H1; // تایم‌فریم عملیاتی برای Hoplite: مثلاً PERIOD_H1 - تایم‌فریم محاسبات اندیکاتورها
input int    Inp_Hoplite_BB_Period = 20; // دوره باندهای بولینگر در Hoplite: معمولاً 20 - برای محاسبه باندها
input double Inp_Hoplite_BB_Deviation = 2.5; // انحراف استاندارد برای باندهای بولینگر: مثلاً 2.5 - تنظیم عرض باندها
input int    Inp_Hoplite_RSI_Period = 14; // دوره RSI در Hoplite: معمولاً 14 - برای محاسبه شاخص قدرت نسبی
input double Inp_Hoplite_RSI_Overbought = 75.0; // سطح اشباع خرید RSI: مثلاً 75.0 - شرط ورود فروش
input double Inp_Hoplite_RSI_Oversold = 25.0; // سطح اشباع فروش RSI: مثلاً 25.0 - شرط ورود خرید
input int    Inp_Hoplite_ADX_Period = 14; // دوره ADX در Hoplite: معمولاً 14 - برای فیلتر رژیم بازار (رونددار یا رنج)
input double Inp_Hoplite_ADX_Threshold = 25.0; // آستانه ADX برای تشخیص بازار رونددار: مثلاً 25.0 - اگر ADX بالاتر باشد، بازار رونددار است
input double Inp_Hoplite_StopLoss_ATR_Multiplier = 2.0; // ضریب ATR برای حد ضرر در Hoplite: مثلاً 2.0 - تنظیم فاصله SL

input ENUM_EXIT_LOGIC Inp_ExitLogic = EXIT_DYNAMIC; // نوع منطق خروج: EXIT_DYNAMIC یا EXIT_RRR - انتخاب روش خروج معاملات
input double Inp_RiskRewardRatio = 3.0; // نسبت ریسک به ریوارد برای خروج RRR: مثلاً 3.0 یعنی TP سه برابر SL

input bool Inp_Show_Kensei_Indicators = false; // نمایش اندیکاتورهای Kensei روی چارت: true برای نمایش - مفید برای توسعه‌دهنده
input bool Inp_Show_Hoplite_Indicators = false; // نمایش اندیکاتورهای Hoplite روی چارت: true برای نمایش - مفید برای توسعه‌دهنده
input bool Inp_Show_OnChart_Display = true; // نمایش پنل اطلاعاتی روی چارت: true برای نمایش - پنل وضعیت EA
input bool Inp_EnableLogging = true; // فعال‌سازی سیستم لاگ: true برای ثبت لاگ‌ها - مفید برای دیباگ

// بخش ثابت‌ها شروع می‌شود - این مقادیر تغییر نمی‌کنند و در سراسر کد استفاده می‌شوند
const string COMMENT_PREFIX = "[ChimeraV2] "; // پیشوند کامنت معاملات: برای شناسایی آسان معاملات این EA در لیست معاملات

#endif  // پایان گارد تعریف - پایان هدر فایل، تمام تعاریف در اینجا به پایان می‌رسد
