// Settings.mqh
// پنل کنترل مرکزی برای تمام ورودی‌ها و ثابت‌ها - این فایل شامل تمام پارامترهای ورودی کاربر و ثابت‌های سیستم است

#ifndef SETTINGS_MQH  // بررسی برای جلوگیری از تعریف مجدد هدر - جلوگیری از کامپایل چندباره
#define SETTINGS_MQH  // تعریف گارد برای جلوگیری از تعریف مجدد

// تعریف enum برای منطق خروج - این enum نوع خروج معاملات را مشخص می‌کند
enum ENUM_EXIT_LOGIC
{
   EXIT_DYNAMIC,    // خروج دینامیک (بر اساس کیجون-سن / خط میانی بولینگر) - خروج پویا بر اساس اندیکاتورها
   EXIT_RRR         // خروج بر اساس نسبت ریسک به ریوارد ثابت - خروج ثابت بر اساس نسبت RRR
};
enum SIGNAL { SIGNAL_NONE, SIGNAL_LONG, SIGNAL_SHORT };  // سیگنال هیچ، خرید، فروش - انواع سیگنال ممکن

// پارامترهای ورودی کاربر - این بخش تمام ورودی‌های قابل تنظیم توسط کاربر را تعریف می‌کند
input double Inp_TotalInitialCapital = 10000.0; // سرمایه اولیه مجازی برای محاسبه حجم معاملات و درصد افت سرمایه - برای شبیه‌سازی ریسک
input double Inp_Kensei_Weight = 0.60; // وزن تخصیص سرمایه به موتور تهاجمی Kensei (بین 0.0 تا 1.0) - درصد سرمایه اختصاصی به Kensei
input double Inp_Hoplite_Weight = 0.40; // وزن تخصیص سرمایه به موتور دفاعی Hoplite (بین 0.0 تا 1.0) - درصد سرمایه اختصاصی به Hoplite
input double Inp_MaxPortfolioDrawdown = 0.09; // حد توقف اضطراری برای کل پورتفولیو (9%) - حداکثر افت سرمایه مجاز برای کل سیستم
input ulong  Inp_BaseMagicNumber = 12345; // شماره مجیک پایه برای تمایز معاملات این اکسپرت - برای شناسایی معاملات این EA

input string Inp_Kensei_Symbols = "EURUSD,GBPUSD,XAUUSD"; // لیست نمادهای معاملاتی برای موتور Kensei (جدا شده با کاما) - نمادهای مجاز برای Kensei
input bool   Inp_Kensei_IsActive = true; // کلید اصلی برای فعال/غیرفعال کردن موتور Kensei - فعال‌سازی موتور Kensei
input ENUM_TIMEFRAMES Inp_Kensei_Timeframe = PERIOD_H1; // تایم‌فریم برای محاسبات موتور Kensei - تایم‌فریم عملیاتی Kensei
input int    Inp_Kensei_Tenkan = 9; // دوره زمانی برای محاسبه خط تنکان-سن در ایچیموکو - دوره تنکان-سن
input int    Inp_Kensei_Kijun = 26; // دوره زمانی برای محاسبه خط کیجون-سن در ایچیموکو - دوره کیجون-سن
input int    Inp_Kensei_SenkouB = 52; // دوره زمانی برای محاسبه سنکو اسپن B در ایچیموکو - دوره سنکو اسپن B
input int    Inp_Kensei_ATR_Period = 14; // دوره زمانی برای محاسبه ATR در حد ضرر - دوره ATR برای SL
input double Inp_Kensei_ATR_Multiplier = 3.0; // ضریب ATR برای محاسبه فاصله حد ضرر اولیه در Kensei - ضریب برای تنظیم SL
input int    Inp_Kensei_Chikou_OpenSpace = 12; // تعداد کندل‌های گذشته برای بررسی شرط فضای باز چیکو اسپن - دوره فضای باز چیکو

input string Inp_Hoplite_Symbols = "EURUSD,GBPUSD,XAUUSD"; // لیست نمادهای معاملاتی برای موتور Hoplite (جدا شده با کاما) - نمادهای مجاز برای Hoplite
input bool   Inp_Hoplite_IsActive = true; // کلید اصلی برای فعال/غیرفعال کردن موتور Hoplite - فعال‌سازی موتور Hoplite
input ENUM_TIMEFRAMES Inp_Hoplite_Timeframe = PERIOD_H1; // تایم‌فریم برای محاسبات موتور Hoplite - تایم‌فریم عملیاتی Hoplite
input int    Inp_Hoplite_BB_Period = 20; // دوره زمانی برای محاسبه باندهای بولینگر در Hoplite - دوره BB
input double Inp_Hoplite_BB_Deviation = 2.5; // تعداد انحراف معیار برای باندهای بولینگر در Hoplite - انحراف استاندارد BB
input int    Inp_Hoplite_RSI_Period = 14; // دوره زمانی برای محاسبه RSI در Hoplite - دوره RSI
input double Inp_Hoplite_RSI_Overbought = 75.0; // سطح اشباع خرید برای RSI در Hoplite - سطح اشباع خرید RSI
input double Inp_Hoplite_RSI_Oversold = 25.0; // سطح اشباع فروش برای RSI در Hoplite - سطح اشباع فروش RSI
input int    Inp_Hoplite_ADX_Period = 14; // دوره زمانی برای محاسبه ADX در فیلتر رژیم Hoplite - دوره ADX
input double Inp_Hoplite_ADX_Threshold = 25.0; // آستانه تشخیص بازار رونددار برای ADX در Hoplite - آستانه ADX
input double Inp_Hoplite_StopLoss_ATR_Multiplier = 2.0; // ضریب ATR برای محاسبه حد ضرر معاملات Hoplite - ضریب ATR برای SL Hoplite

input ENUM_EXIT_LOGIC Inp_ExitLogic = EXIT_DYNAMIC; // نوع منطق خروج (دینامیک یا RRR) - انتخاب نوع خروج
input double Inp_RiskRewardRatio = 3.0; // نسبت ریسک به ریوارد برای منطق خروج RRR - نسبت RRR

input bool Inp_Show_Kensei_Indicators = false; // نمایش اندیکاتورهای Kensei روی چارت (برای توسعه‌دهنده) - نمایش اندیکاتورهای Kensei
input bool Inp_Show_Hoplite_Indicators = false; // نمایش اندیکاتورهای Hoplite روی چارت (برای توسعه‌دهنده) - نمایش اندیکاتورهای Hoplite
input bool Inp_Show_OnChart_Display = true; // نمایش پنل اطلاعاتی روی چارت - نمایش پنل روی چارت

input bool Inp_EnableLogging = true; // کلید فعال/غیرفعال کردن لاگ (انتقال از Logging.mqh) - فعال‌سازی سیستم لاگ

// ثابت‌ها - ثابت‌های سیستم که تغییر نمی‌کنند
const string COMMENT_PREFIX = "[ChimeraV2] "; // پیشوند کامنت برای معاملات جهت شناسایی آسان - پیشوند برای کامنت معاملات

#endif  // پایان گارد تعریف - پایان هدر
