// Settings.mqh
// این فایل به عنوان پنل کنترل مرکزی عمل می‌کند و تمام پارامترهای ورودی کاربر (inputs) و ثابت‌های سیستم را تعریف می‌کند.
// این تنظیمات اجازه می‌دهد تا کاربر سیستم را سفارشی‌سازی کند بدون نیاز به تغییر کد اصلی.
// تمام پارامترها با پیشوند Inp_ شروع می‌شوند تا به راحتی شناسایی شوند.
// این فایل برای بهینه‌سازی در متاتریدر ۵ طراحی شده و از enumها برای گزینه‌های انتخابی استفاده می‌کند تا خطای انسانی کاهش یابد.

// جلوگیری از تکرار تعریف هدر با استفاده از گارد پیش‌پردازنده برای جلوگیری از کامپایل چندباره
#ifndef SETTINGS_MQH
#define SETTINGS_MQH

// تعریف enum برای منطق خروج از معامله - این enum گزینه‌های خروج را محدود می‌کند تا کاربر گزینه اشتباه انتخاب نکند
enum ENUM_EXIT_LOGIC
{
   EXIT_DYNAMIC,    // خروج دینامیک: بر اساس اندیکاتورها مانند کیجون-سن (برای کنسی) یا خط میانی بولینگر (برای هاپلیت) - مناسب برای بازارهای پویا
   EXIT_RRR         // خروج ثابت: بر اساس نسبت ریسک به ریوارد (RRR) - مناسب برای استراتژی‌های ثابت و کنترل‌شده
};

// تعریف enum برای انواع سیگنال‌ها - SIGNAL_NONE نشان‌دهنده عدم سیگنال است تا در کد به راحتی چک شود
enum SIGNAL { SIGNAL_NONE, SIGNAL_LONG, SIGNAL_SHORT };

// پارامترهای ورودی کاربر - این بخش اجازه سفارشی‌سازی را می‌دهد
// سرمایه اولیه مجازی برای محاسبات
input double Inp_TotalInitialCapital = 10000.0; // سرمایه اولیه مجازی: برای محاسبات حجم لات و افت سرمایه استفاده می‌شود - این مقدار واقعی نیست، بلکه مبنای محاسباتی است

// وزن‌های تخصیص سرمایه به موتورها - مجموع باید ۱.۰ باشد، اما سیستم نرمال‌سازی دارد تا خطای انسانی را مدیریت کند
input double Inp_Kensei_Weight = 0.60; // وزن تخصیص سرمایه برای موتور کنسی (از ۰.۰ تا ۱.۰) - موتور تهاجمی برای روندها
input double Inp_Hoplite_Weight = 0.40; // وزن تخصیص سرمایه برای موتور هاپلیت (از ۰.۰ تا ۱.۰) - موتور دفاعی برای رنج‌ها

// مدیریت ریسک پورتفولیو
input double Inp_MaxPortfolioDrawdown = 0.09; // حداکثر درصد افت سرمایه پورتفولیو (مثلاً ۰.۰۹ = ۹٪) - اگر بیش از این شود، تمام پوزیشن‌ها بسته می‌شوند
input double Inp_Risk_Percent_Per_Trade=1;
// شناسایی معاملات
input ulong  Inp_BaseMagicNumber = 12345; // شماره جادویی پایه: برای شناسایی معاملات اکسپرت در متاتریدر استفاده می‌شود - باید منحصر به فرد باشد

// تنظیمات موتور کنسی (Kensei) - موتور روندگیر بر اساس ایچیموکو
input string Inp_Kensei_Symbols = "EURUSD,GBPUSD,XAUUSD"; // نمادهای معاملاتی کنسی: جدا شده با کاما - مثلاً EURUSD برای جفت ارز یورو دلار
input bool   Inp_Kensei_IsActive = true; // فعال کردن موتور کنسی: true برای فعال، false برای غیرفعال
input ENUM_TIMEFRAMES Inp_Kensei_Timeframe = PERIOD_H1; // تایم‌فریم کنسی: مثلاً PERIOD_H1 برای ساعتی
input int    Inp_Kensei_Tenkan = 9; // دوره تنکان-سن در ایچیموکو: میانگین کوتاه‌مدت
input int    Inp_Kensei_Kijun = 26; // دوره کیجون-سن در ایچیموکو: میانگین میان‌مدت، برای خروج دینامیک استفاده می‌شود
input int    Inp_Kensei_SenkouB = 52; // دوره سنکو اسپن بی در ایچیموکو: برای ابر کومو
input int    Inp_Kensei_ATR_Period = 14; // دوره ATR برای محاسبه حد ضرر کنسی
input double Inp_Kensei_ATR_Multiplier = 3.0; // ضریب ATR برای فاصله حد ضرر کنسی - مثلاً ۳ برابر ATR
input int    Inp_Kensei_Chikou_OpenSpace = 12; // دوره فضای باز چیکو اسپن: برای چک فضای باز گذشته - نکته: بلوپرینت ۱۲، اما ممکن است ۱۲۰ بهتر باشد، با بک‌تست چک کنید

// تنظیمات موتور هاپلیت (Hoplite) - موتور بازگشت به میانگین بر اساس بولینگر، RSI و ADX
input string Inp_Hoplite_Symbols = "EURUSD,GBPUSD,XAUUSD"; // نمادهای معاملاتی هاپلیت: جدا شده با کاما
input bool   Inp_Hoplite_IsActive = true; // فعال کردن موتور هاپلیت: true برای فعال
input ENUM_TIMEFRAMES Inp_Hoplite_Timeframe = PERIOD_H1; // تایم‌فریم هاپلیت
input int    Inp_Hoplite_BB_Period = 20; // دوره بولینگر بندز: برای محاسبه باندها
input double Inp_Hoplite_BB_Deviation = 2.5; // انحراف استاندارد بولینگر بندز: برای عرض باندها
input int    Inp_Hoplite_RSI_Period = 14; // دوره RSI: برای تشخیص بیش‌خرید/بیش‌فروش
input double Inp_Hoplite_RSI_Overbought = 75.0; // سطح بیش‌خرید RSI: بالای این مقدار فروش
input double Inp_Hoplite_RSI_Oversold = 25.0; // سطح بیش‌فروش RSI: پایین این مقدار خرید
input int    Inp_Hoplite_ADX_Period = 14; // دوره ADX: برای تشخیص روند
input double Inp_Hoplite_ADX_Threshold = 25.0; // آستانه ADX: بالای این مقدار بازار رونددار است و سیگنال نمی‌دهد
input double Inp_Hoplite_StopLoss_ATR_Multiplier = 2.0; // ضریب ATR برای حد ضرر هاپلیت

// منطق خروج عمومی
input ENUM_EXIT_LOGIC Inp_ExitLogic = EXIT_DYNAMIC; // نوع منطق خروج: دینامیک یا RRR
input double Inp_RiskRewardRatio = 3.0; // نسبت ریسک به ریوارد برای خروج RRR: مثلاً ۳ یعنی TP سه برابر SL

// نمایش و لاگینگ
input bool Inp_Show_Kensei_Indicators = false; // نمایش اندیکاتورهای کنسی روی چارت: برای دیباگینگ
input bool Inp_Show_Hoplite_Indicators = false; // نمایش اندیکاتورهای هاپلیت روی چارت
input bool Inp_Show_OnChart_Display = true; // نمایش پنل اطلاعات روی چارت: برای نظارت زنده
input bool Inp_EnableLogging = true; // فعال کردن سیستم لاگینگ: برای ثبت رویدادها در فایل

// ثابت‌های سیستم - این‌ها تغییر نمی‌کنند
const string COMMENT_PREFIX = "[ChimeraV2] "; // پیشوند کامنت معاملات: برای شناسایی در لیست معاملات متاتریدر

// پایان گارد پیش‌پردازنده
#endif
