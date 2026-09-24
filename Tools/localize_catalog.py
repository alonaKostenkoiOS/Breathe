#!/usr/bin/python3
"""Build-time localization catalog drafter and completeness audit.

No runtime dependency is introduced. Existing reviewed translations are never
overwritten. Format placeholders are protected before translation and checked
again before the catalog is written atomically.
"""
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
from pathlib import Path
import re
import subprocess
import sys
import time
import urllib.parse
import urllib.request

CATALOG = Path("App/Resources/Localizable.xcstrings")
LOCALES = ("uk", "es", "pt-BR", "de", "fr", "it", "pl", "tr", "ja", "ko", "zh-Hans")
API_LOCALE = {"pt-BR": "pt", "zh-Hans": "zh-CN"}
FORMAT_ONLY = re.compile(r"^(?:%@|%d|%lld|%\.\d+f|%+|/|\s)+$")
BATCH_SEPARATOR = "987654321098765"
SEMANTIC_KEYS = {
    "plan.if_then.create": ("Create an If → Then plan", "Create personal plan action."),
    "plan.if_then.if_label": ("If this happens", "If-Then plan condition label."),
    "plan.if_then.if_placeholder": ("For example, I reach for my phone automatically", "If-Then plan condition example."),
    "plan.if_then.then_label": ("Then I will", "If-Then plan response label."),
    "plan.if_then.then_placeholder": ("For example, close it and take three breaths", "If-Then plan response example."),
    "plan.if_then.privacy": ("This personal plan stays on your device.", "Plan privacy note."),
    "risk_window.title": ("Risk window", "Risk-window editor title."),
    "risk_window.create": ("Add a risk window", "Create manual risk window."),
    "risk_window.manual.title": ("When may a difficult moment happen?", "Manual risk-window prompt."),
    "risk_window.manual.detail": ("Breathe stores local clock components so this stays aligned with your routine.", "Risk window persistence explanation."),
    "risk_window.time": ("Time", "Risk window time field."),
    "spending.pause_list.title": ("Pause List", "Private delayed-purchase list title."),
    "spending.pause_list.detail": ("Save an item privately and decide after the waiting period.", "Pause List explanation."),
    "spending.pause_list.open": ("Open Pause List", "Open delayed purchase list."),
    "spending.pause_list.item": ("What do you want to buy?", "Pause List item field."),
    "spending.pause_list.price": ("Price", "Pause List price field."),
    "spending.pause_list.reason": ("Why do you want it? (optional)", "Pause List reason field."),
    "spending.pause_list.wait": ("Waiting period", "Pause List delay picker."),
    "spending.pause_list.add": ("Add privately", "Save Pause List item."),
    "digital.screen_time.fallback": ("Screen Time controls require Apple entitlements. Breathe still supports manual pauses, timers, and urge logging without them.", "Graceful fallback when FamilyControls entitlement is unavailable."),
    "widget.discreet.title": ("A moment for you", "Discreet widget title that never reveals the active program."),
    "widget.discreet.detail": ("Your Breathe check-in is ready.", "Discreet lock-screen-safe widget copy."),
    "widget.program.detail": ("Pause, breathe, and choose your next step.", "Program-aware widget support copy without sensitive metrics."),
    "widget.rescue.action": ("Start Rescue", "Widget quick action."),
    "widget.description": ("Private, one-tap support for a difficult moment.", "Widget gallery description."),
    "notification.discreet.title": ("Breathe", "Discreet notification title."),
    "notification.discreet.body": ("Your Breathe check-in is ready.", "Discreet notification body; must not reveal program or behavior."),
    "brand.regain_control": ("Regain control, one urge at a time.", "Umbrella brand message."),
    "program.selection.title": ("What would you like to regain control over?", "Program selection title."),
    "program.selection.detail": ("Start with one program. You can add or change programs later.", "Program selection explanation."),
    "program.selection.continue": ("Continue", "Continue after choosing a program."),
    "program.nicotine.name": ("Breathe Nicotine", "Nicotine program name."),
    "program.digital.name": ("Breathe Digital", "Digital balance program name."),
    "program.spending.name": ("Breathe Spending", "Intentional spending program name."),
    "program.alcohol.name": ("Breathe Alcohol", "Alcohol support program name; must not imply treatment."),
    "program.gambling.name": ("Breathe Gambling", "Gambling harm-prevention program name."),
    "program.nicotine.description": ("Build a plan for cigarettes, vaping, or other nicotine products.", "Neutral nicotine program description."),
    "program.digital.description": ("Use your phone and social media more intentionally.", "Digital balance description; do not diagnose addiction."),
    "program.spending.description": ("Pause purchase impulses and make more intentional decisions.", "Spending program description; not financial advice."),
    "program.alcohol.description": ("Reflect on drinking and prepare for difficult situations safely.", "Alcohol program description; not medical treatment."),
    "program.gambling.description": ("Pause gambling urges and strengthen barriers that protect you.", "Gambling harm-prevention description."),
    "privacy.local.title": ("Private by default", "Privacy card title."),
    "privacy.local.detail": ("Your program data stays on this device unless you choose to export it.", "Local storage explanation."),
    "privacy.all_data_local": ("Your program history stays on this device.", "Settings privacy statement."),
    "privacy.export.action": ("Prepare data export", "Creates a local JSON export."),
    "privacy.share_export": ("Share prepared export", "Opens the system share sheet."),
    "programs.title": ("Programs", "Settings program-management section."),
    "program.primary": ("Primary", "Current primary program badge."),
    "program.make_primary": ("Make primary", "Switch the primary program."),
    "program.pause": ("Pause", "Pause a recovery program."),
    "program.resume": ("Resume", "Resume a paused program."),
    "program.archive": ("Archive", "Archive program without deleting history."),
    "program.start_another": ("Start another program", "Add another program."),
    "program.delete.title": ("Permanently delete this program?", "Destructive deletion confirmation."),
    "program.delete.action": ("Delete program and its data", "Destructive program deletion action."),
    "program.delete.detail": ("This removes the program’s urges, plans, risk windows, and history. This cannot be undone.", "Program deletion consequence."),
    "platform.migration.title": ("Breathe now supports more goals", "Non-blocking migration explanation title."),
    "platform.migration.detail": ("Your quit plan and all existing progress are unchanged in Breathe Nicotine. You can explore other programs whenever you’re ready.", "Legacy nicotine migration reassurance."),
    "rescue.start": ("Start Rescue", "Immediate support action."),
    "rescue.start.detail": ("Pause before the impulse becomes an action.", "Rescue action detail."),
    "rescue.start.hint": ("Opens immediate offline support.", "VoiceOver hint."),
    "rescue.title": ("Breathe Rescue", "Shared Rescue flow title."),
    "rescue.check_in.title": ("How strong is the urge right now?", "Only question before Rescue begins."),
    "rescue.check_in.detail": ("Choose the closest number. You can begin immediately.", "Intensity prompt help."),
    "rescue.begin": ("Begin", "Starts the recommended Rescue strategy."),
    "rescue.check_in_now": ("Check in now", "Ends timer and reflects."),
    "rescue.reflect.title": ("What happened?", "Delayed Rescue reflection title."),
    "rescue.reflect.detail": ("A difficult moment happened. What you learned and achieved still matters.", "Non-judgmental setback copy."),
    "rescue.outcome.urge_passed": ("The urge became weaker", "Shared Rescue outcome."),
    "rescue.outcome.delayed": ("I delayed the action", "Shared Rescue outcome."),
    "rescue.outcome.reduced": ("I reduced the action", "Shared Rescue outcome."),
    "rescue.outcome.behavior_occurred": ("The behavior happened", "Neutral shared setback outcome."),
    "rescue.outcome.still_dealing": ("I’m still dealing with it", "Shared Rescue outcome."),
    "rescue.outcome.urgePassed": ("Urge became weaker", "History outcome."),
    "rescue.outcome.behaviorOccurred": ("Behavior happened", "History outcome."),
    "rescue.outcome.stillDealingWithIt": ("Still dealing with it", "History outcome."),
    "rescue.helpful.question": ("Was this strategy helpful?", "Rescue usefulness feedback."),
    "home.next_step.title": ("Your next step", "Adaptive home heading."),
    "home.prepare.title": ("Prepare", "Preparation card title."),
    "home.insight.title": ("A personal observation", "Home insight heading; avoid medical claims."),
    "home.next.nicotine": ("Keep water nearby and choose what you’ll do with your next urge.", "Nicotine preparation action."),
    "home.next.digital": ("Choose one phone-free period for today.", "Digital preparation action."),
    "home.next.spending": ("Choose a waiting period for your next unplanned purchase.", "Spending preparation action."),
    "home.next.alcohol": ("Plan a safe exit and a non-alcoholic option before your next event.", "Alcohol preparation action."),
    "home.next.gambling": ("Review your access-to-money barrier before a difficult moment.", "Gambling preparation action."),
    "plan.if_then.title": ("Your If → Then plan", "Personal behavior plan title."),
    "insight.empty": ("Log a few difficult moments and Breathe will begin showing careful, personal observations.", "No insights state."),
    "insight.observation": ("Breathe is learning which pauses are useful for you. You can correct any suggestion.", "Early insight without overclaiming."),
    "insight.confidence.early": ("Early observation", "Low-confidence insight label."),
    "insight.early.detail": ("More moments are needed before Breathe calls this a pattern.", "Low confidence explanation."),
    "urges.empty.title": ("No urges logged yet", "Empty urge history title."),
    "urges.empty.detail": ("Recording difficult moments helps Breathe learn what support is useful.", "Empty urge history detail."),
    "progress.personal.title": ("Your progress", "Generic program progress title."),
    "progress.personal.detail": ("Progress is more than a perfect streak. Pauses and what you learn both count.", "Non-streak progress explanation."),
    "progress.urges_logged": ("Urges logged", "Progress metric."),
    "progress.pauses_created": ("Helpful pauses", "Progress metric."),
    "notifications.discreet.title": ("Discreet notifications", "Privacy notification setting."),
    "notifications.discreet.detail": ("Hide program names and sensitive details from notification previews.", "Discreet notification explanation."),
    "alcohol.safety.title": ("A safety check before you begin", "Alcohol medical-safety screening title."),
    "alcohol.safety.detail": ("Suddenly stopping alcohol can be dangerous for some people. These questions help Breathe show appropriate safety information; they do not provide a diagnosis.", "Safety-critical alcohol explanation. Requires clinical review."),
    "alcohol.safety.heavy_use": ("I frequently drink heavily", "Alcohol withdrawal-risk screening item. Requires clinical review."),
    "alcohol.safety.withdrawal": ("I have had withdrawal symptoms before", "Alcohol safety screening item."),
    "alcohol.safety.shaking": ("I shake or sweat when I do not drink", "Alcohol safety screening item."),
    "alcohol.safety.seizure": ("I have had a withdrawal seizure", "Alcohol emergency-risk screening item."),
    "alcohol.safety.confusion": ("I have had hallucinations or severe confusion", "Alcohol emergency-risk screening item."),
    "alcohol.safety.normal": ("I need alcohol to feel normal", "Alcohol safety screening item."),
    "alcohol.safety.pregnancy": ("I am pregnant or may be pregnant", "Alcohol professional-support screening item."),
    "alcohol.safety.emergency": ("A medical emergency may be happening now", "Alcohol current emergency screening item."),
    "alcohol.safety.warning": ("Do not make an unsupported abrupt-stop plan. Contact a qualified healthcare professional. Severe shaking, seizures, hallucinations, or confusion need emergency care.", "Safety-critical alcohol withdrawal warning. Requires clinician and translator review."),
    "alcohol.transport.title": ("Do not drive", "Prominent alcohol transport safety title."),
    "alcohol.transport.detail": ("If you have been drinking, arrange a safe way home or contact someone you trust.", "Alcohol safe transport action."),
    "gambling.safety.title": ("Support and safety", "Gambling safety onboarding title."),
    "gambling.safety.detail": ("Breathe can help you pause urges and reach self-exclusion or professional resources. It is not treatment or financial advice.", "Gambling safety scope."),
    "gambling.safety.self_harm": ("Gambling-related distress has led to thoughts of self-harm or suicide", "Gambling crisis screening. Requires specialist review."),
    "gambling.safety.immediate_danger": ("I may be in immediate danger", "Gambling crisis screening."),
    "gambling.safety.resources_free": ("Crisis and self-exclusion resources are always available without payment.", "Free safety resource statement."),
    "gambling.safety.warning": ("You deserve immediate human support. Contact local emergency or crisis services, or a person you trust, now.", "Gambling crisis warning; localized resources must be supplied by country."),
    "gambling.self_exclusion.action": ("Open self-exclusion resources", "Always-free gambling harm-prevention action."),
    "safety.review.action": ("Review safety guidance", "Evaluates safety answers locally."),
    "safety.acknowledge.action": ("I understand — continue with supportive logging", "Acknowledges warning without waiving care."),
    "safety.emergency.title": ("Get urgent help now", "Emergency safety title."),
    "safety.professional.title": ("Talk with a qualified professional", "Professional support title."),
    "safety.emergency.action": ("Call emergency services", "Country-dependent emergency action; currently uses system emergency number."),
}

for strategy_id, title, instruction in [
    ("breathe", "Calm breathing", "Take slow, comfortable breaths for one minute."),
    ("urge_surf", "Ride the wave", "Notice the urge without fighting it and give it time to change."),
    ("water", "Drink water", "Take a few slow sips and change the familiar sequence."),
    ("walk", "Take a short walk", "Move to a different place for two minutes if it is safe."),
    ("delay", "Create a short delay", "Wait for the timer before deciding what to do next."),
    ("contact", "Contact someone you trust", "Use your prepared communication action or the system Share Sheet."),
    ("intention", "Check your intention", "Name what you wanted to do before you opened the app."),
    ("put_down", "Put the device down", "Place the device out of reach for two minutes."),
    ("focus_timer", "Start a focus pause", "Give one chosen activity your attention until the timer ends."),
    ("alternative", "Choose an alternative", "Pick the non-alcoholic or offline alternative you prepared."),
    ("pause_list", "Add it to your Pause List", "Save the item privately and choose when to review it."),
    ("compare_goal", "Compare with your goal", "Pause and consider what this amount could support instead."),
    ("leave", "Leave the situation", "Move away from the store, site, or situation if you safely can."),
    ("remove_card", "Add a payment barrier", "Close the checkout and consider removing stored payment details."),
    ("transport", "Arrange safe transport", "Do not drive. Arrange a safe way home."),
    ("professional", "Open professional support", "Choose a qualified local support resource."),
    ("delay_deposit", "Delay the deposit", "Do not add money now. Let the cooling-off timer run."),
    ("close_app", "Close the gambling app", "Close the app or site and move away from the device."),
    ("cooling_off", "Start a cooling-off pause", "Keep access blocked until the timer ends."),
    ("self_exclusion", "Open self-exclusion", "Review the official self-exclusion options available in your country."),
]:
    SEMANTIC_KEYS[f"strategy.{strategy_id}.title"] = (title, "Program Rescue strategy title.")
    SEMANTIC_KEYS[f"strategy.{strategy_id}.instruction"] = (instruction, "Program Rescue strategy instruction.")
EXTRA_KEYS = {
    "Start Rescue": "App Intent title and shortcut label for immediate support.",
    "Open immediate, private support in Breathe.": "App Intent description.",
    "Take one slow breath. Breathe is ready when you are.": "Supportive App Intent response.",
    "Log an urge": "Neutral cross-program App Intent title.",
    "Log urge": "Short App Shortcut title.",
    "Privately record an urge for your active Breathe program.": "App Intent description.",
    "Open Breathe to choose a program first.": "App Intent response when no active program exists.",
    "Logged privately. Your progress still matters.": "Supportive cross-program App Intent confirmation.",
    "Craving Coach": "Name of the personalized, in-the-moment craving support flow.",
    "Close coach": "VoiceOver label for closing Craving Coach.",
    "Let’s get through this moment": "Warm, supportive Craving Coach check-in title.",
    "A quick check-in helps Breathe choose support that fits.": "Explains why Coach asks two short questions.",
    "How strong is the craving?": "Craving Coach intensity question.",
    "Choose the closest match, or continue if you’re not sure.": "Trigger question reassurance; selecting a trigger is optional.",
    "Find support": "Primary action that creates a Coach recommendation.",
    "Try this first": "Heading for the recommended coping strategy.",
    "Other options": "Heading for alternative coping strategies.",
    "Change my answers": "Returns to the Coach check-in.",
    "Stay with this moment": "Fallback title during a Coach exercise.",
    "Check in now": "Ends an exercise early and opens the result check-in.",
    "It feels easier": "Coach result: craving intensity improved.",
    "It feels the same": "Coach result: craving intensity is unchanged.",
    "It feels stronger": "Coach result: craving intensity increased.",
    "Try another strategy": "Returns to the Coach strategy choices.",
    "We’re starting with a simple technique.": "Transparent reason for a default recommendation when little data exists.",
    "This matches the situation you selected.": "Transparent reason for a trigger-based recommendation.",
    "This helped you before.": "Transparent reason for a history-based recommendation.",
    "Ride the wave": "Coach strategy: observe an urge until it passes; not surfing.",
    "Calm breathing": "Coach strategy title.",
    "Five senses": "Coach grounding strategy title.",
    "Change the scene": "Coach strategy: briefly move away from a familiar smoking context.",
    "Keep hands and mouth busy": "Coach replacement-action strategy title.",
    "Remember your reason": "Coach motivation strategy title.",
    "Give the urge time to rise and pass.": "Short summary of the ride-the-wave strategy.",
    "Slow your breathing for one minute.": "Short summary of the breathing strategy.",
    "Reconnect with what is around you.": "Short summary of the grounding strategy.",
    "Break the familiar routine with movement.": "Short summary of the change-scene strategy.",
    "Use a simple smoke-free replacement.": "Short summary of a replacement action; smoke-free means without smoking.",
    "Reconnect with what matters to you.": "Short summary of the motivation strategy.",
    "Notice the urge without fighting it. It can rise, peak, and pass. Stay here until the timer ends.": "Ride-the-wave exercise instruction; do not guarantee the craving disappears.",
    "Follow the circle. Breathe in gently as it grows, then breathe out as it becomes smaller.": "Breathing exercise instruction.",
    "Name five things you see, four you can feel, three you hear, two you smell, and one you taste.": "Five-senses grounding instruction.",
    "Stand up and move somewhere different. If you can, walk for a minute and take a sip of water.": "Change-scene exercise instruction.",
    "Hold a pen, glass, or small object. Try water, gum, or a crunchy snack if one is nearby.": "Hands-and-mouth replacement exercise instruction.",
    "Read your reason slowly. Imagine the next choice that keeps you moving toward it.": "Motivation exercise instruction.",
    "Open Craving Coach": "Dashboard action opening personalized craving support.",
    "Get support that fits this moment": "Dashboard subtitle for Craving Coach.",
    "Opens personalized support for a craving": "VoiceOver hint for the Craving Coach dashboard action.",
    "Try Craving Coach": "Action offered after logging an ongoing craving.",
    "Language": "Settings section title for choosing the app language.",
    "App language": "Label for the app language picker.",
    "System Default": "Use the language selected for Breathe by iOS.",
    "Changing the language does not change your currency, quit date, or saved progress.": "Language setting privacy and data reassurance.",
    "Record a craving and whether you resisted it.": "App Intent description.",
    "I resisted it": "Boolean App Intent parameter; resisted means did not smoke.",
    "Logged. Every craving you resist is progress.": "Supportive Siri confirmation after resisting a craving.",
    "Logged. You had a slip, and your progress still matters.": "Supportive Siri confirmation after smoking; slip must never be translated as failure.",
    "Log a craving in Breathe": "Spoken shortcut phrase.",
    "Within a day of quitting, the carbon monoxide in your blood drops and oxygen reaches your heart and muscles more easily.": "Estimated offline health fact; do not imply a guarantee.",
    "Most people notice food tasting better within just two days of their last cigarette.": "Estimated offline health fact; preserve the qualifier most people.",
    "One year smoke-free roughly halves your excess risk of coronary heart disease.": "Estimated offline health fact; preserve roughly.",
    "Within 24 hours of your last cigarette, the carbon monoxide level in your blood returns to normal.": "Estimated health fact from the bundled remote-content seed.",
    "After just two days, nerve endings begin to regrow and your senses of taste and smell start to sharpen.": "Estimated health fact; recovery varies by person.",
    "Two to twelve weeks in, your circulation improves and physical activity becomes noticeably easier.": "Estimated health fact; recovery varies by person.",
    "By nine months, the cilia in your lungs have largely recovered, cutting coughing and infections.": "Estimated health fact; preserve largely rather than guarantee full recovery.",
    "After one year smoke-free, your excess risk of coronary heart disease is about half that of a smoker.": "Estimated health fact; preserve about.",
    "Every craving you ride out rewires the habit loop a little more — urges peak and pass in just a few minutes.": "Supportive behavioral fact; avoid guarantees.",
    "Pulse normalises": "Estimated health milestone title.",
    "Heart rate and blood pressure begin to drop back toward normal.": "Estimated health milestone detail.",
    "Carbon monoxide clears": "Estimated health milestone title.",
    "Carbon monoxide in your blood falls to a normal level, so more oxygen reaches your organs.": "Estimated health milestone detail.",
    "Heart attack risk falls": "Estimated health milestone title.",
    "Your risk of a heart attack starts to decrease.": "Estimated health milestone detail.",
    "Taste & smell return": "Estimated health milestone title.",
    "Nerve endings start to regrow and your senses of smell and taste sharpen.": "Estimated health milestone detail.",
    "Breathing eases": "Estimated health milestone title.",
    "Bronchial tubes relax and lung capacity increases, making breathing easier.": "Estimated health milestone detail.",
    "Circulation improves": "Estimated health milestone title.",
    "Blood flow improves, making walking and exercise noticeably easier.": "Estimated health milestone detail.",
    "Lungs clear out": "Estimated health milestone title.",
    "Cilia regrow, clearing mucus and cutting coughing and shortness of breath.": "Estimated health milestone detail.",
    "Lung function climbs": "Estimated health milestone title.",
    "Lung function can improve by up to 30%.": "Estimated health milestone detail; preserve can and up to.",
    "Heart disease risk halves": "Estimated health milestone title.",
    "Your risk of coronary heart disease is about half that of a smoker.": "Estimated health milestone detail; preserve about.",
    "Cancer risk drops": "Estimated health milestone title.",
    "Risk of several cancers falls and stroke risk approaches that of a non-smoker.": "Estimated health milestone detail.",
    "Lung cancer risk halves": "Estimated health milestone title.",
    "Your risk of dying from lung cancer is roughly half that of a smoker.": "Estimated health milestone detail; preserve roughly.",
}
GLOSSARY_COMMENTS = {
    "Craving": "Urge to smoke; supportive, non-clinical wording.",
    "Trigger": "Situation that can prompt an urge to smoke.",
    "Smoke-free": "Time lived without smoking.",
    "Craving Rescue": "Name of the calm guided support experience.",
    "Savings goal": "A personal purchase or experience funded by money not spent on cigarettes.",
    "Cigarettes avoided": "Estimated number not smoked since the quit date.",
    "Money saved": "Estimated money not spent on cigarettes.",
    "Life regained": "Estimated additional life time associated with cigarettes avoided; do not imply certainty.",
    "Quit date & time": "The date and time the user stopped smoking.",
}
REVIEWED_OVERRIDES = {
    "Privately record an urge for your active Breathe program.": {"it": "Registra in privato un impulso per il programma Breathe attivo."},
    "Craving Coach": {"uk": "Підтримка під час тяги"},
    "Close coach": {"uk": "Закрити підтримку"},
    "Let’s get through this moment": {"uk": "Пройдемо цей момент разом"},
    "A quick check-in helps Breathe choose support that fits.": {"uk": "Кілька коротких запитань допоможуть Breathe підібрати доречну підтримку."},
    "How strong is the craving?": {"uk": "Наскільки сильна тяга?"},
    "Find support": {"uk": "Підібрати підтримку"},
    "Try this first": {"uk": "Спробуйте спочатку"},
    "It feels easier": {"uk": "Стало легше"},
    "It feels the same": {"uk": "Без змін"},
    "It feels stronger": {"uk": "Тяга посилилася"},
    "Ride the wave": {"uk": "Перечекати хвилю"},
    "Calm breathing": {"uk": "Спокійне дихання"},
    "Five senses": {"uk": "П’ять чуттів"},
    "Change the scene": {"uk": "Змінити обстановку"},
    "Keep hands and mouth busy": {"uk": "Зайняти руки й рот"},
    "Remember your reason": {"uk": "Згадати свою причину"},
    "Open Craving Coach": {"uk": "Відкрити підтримку", "ko": "흡연 욕구 코치 열기"},
    "Get support that fits this moment": {"uk": "Отримайте підтримку, доречну саме зараз"},
    "Try Craving Coach": {"uk": "Спробувати підтримку"},
    "Home": {"uk": "Головна", "es": "Inicio", "pt-BR": "Início", "de": "Start", "fr": "Accueil", "it": "Home", "pl": "Strona główna", "tr": "Ana Sayfa", "ja": "ホーム", "ko": "홈", "zh-Hans": "首页"},
    "Cravings": {"uk": "Тяга", "es": "Ganas de fumar", "pt-BR": "Vontades de fumar", "de": "Rauchverlangen", "fr": "Envies de fumer", "it": "Voglia di fumare", "pl": "Chęć zapalenia", "tr": "Sigara isteği", "ja": "吸いたい気持ち", "ko": "흡연 욕구", "zh-Hans": "烟瘾"},
    "Craving Rescue": {"uk": "Допомога під час тяги", "es": "Ayuda ante las ganas de fumar", "pt-BR": "Ajuda para a vontade de fumar", "de": "Hilfe bei Rauchverlangen", "fr": "Aide en cas d’envie", "it": "Aiuto contro la voglia", "pl": "Pomoc przy chęci zapalenia", "tr": "Sigara İsteği Desteği", "ja": "吸いたい気持ちのサポート", "ko": "흡연 욕구 도움", "zh-Hans": "烟瘾缓解"},
    "Trigger": {"uk": "Тригер", "es": "Desencadenante", "pt-BR": "Gatilho", "de": "Auslöser", "fr": "Déclencheur", "it": "Fattore scatenante", "pl": "Wyzwalacz", "tr": "Tetikleyici", "ja": "きっかけ", "ko": "유발 요인", "zh-Hans": "诱因"},
    "Life regained": {"uk": "Повернуто часу життя", "es": "Tiempo de vida recuperado", "pt-BR": "Tempo de vida recuperado", "de": "Zurückgewonnene Lebenszeit", "fr": "Temps de vie regagné", "it": "Tempo di vita recuperato", "pl": "Odzyskany czas życia", "tr": "Geri kazanılan yaşam süresi", "ja": "取り戻した時間", "ko": "되찾은 삶의 시간", "zh-Hans": "挽回的生命时间"},
    "Language": {"pt-BR": "Idioma"},
    "Logged. Every craving you resist is progress.": {
        "uk": "Записано. Кожна подолана тяга — це прогрес.", "es": "Registrado. Cada antojo que superas es un avance.",
        "pt-BR": "Registrado. Cada vontade que você supera é um avanço.", "de": "Gespeichert. Jedes Verlangen, dem du widerstehst, ist ein Fortschritt.",
        "fr": "Enregistré. Chaque envie surmontée est un progrès.", "it": "Registrato. Ogni voglia a cui resisti è un passo avanti.",
        "pl": "Zapisano. Każda pokonana chęć zapalenia to postęp.", "tr": "Kaydedildi. Direndiğin her sigara isteği bir ilerlemedir.",
        "ja": "記録しました。吸いたい気持ちを乗り越えるたびに、前へ進んでいます。", "ko": "기록했어요. 흡연 욕구를 이겨 낼 때마다 한 걸음 나아가는 거예요.",
        "zh-Hans": "已记录。每一次抵住吸烟冲动，都是进步。",
    },
    "Logged. You had a slip, and your progress still matters.": {
        "uk": "Записано. Стався зрив, але ваш прогрес і далі важливий.", "es": "Registrado. Tuviste un desliz, pero tu progreso sigue contando.",
        "pt-BR": "Registrado. Houve um deslize, mas seu progresso continua valendo.", "de": "Gespeichert. Es gab einen Ausrutscher, doch dein Fortschritt zählt weiterhin.",
        "fr": "Enregistré. Vous avez eu un écart, mais vos progrès comptent toujours.", "it": "Registrato. C’è stato uno scivolone, ma i tuoi progressi contano ancora.",
        "pl": "Zapisano. Zdarzyło Ci się zapalić, ale Twoje postępy nadal mają znaczenie.", "tr": "Kaydedildi. Bir kez sigara içtin, ama ilerlemen hâlâ önemli.",
        "ja": "記録しました。吸ってしまったとしても、これまでの歩みは大切です。", "ko": "기록했어요. 한 번 피웠더라도 지금까지의 노력은 여전히 소중해요.",
        "zh-Hans": "已记录。即使这次吸了烟，你已经取得的进步依然重要。",
    },
    "This moment will pass. Stay with your breath.": {
        "uk": "Ця мить мине. Зосередьтеся на диханні.", "es": "Este momento pasará. Vuelve a tu respiración.",
        "pt-BR": "Este momento vai passar. Volte a atenção para a respiração.", "de": "Dieser Moment geht vorüber. Konzentriere dich auf deinen Atem.",
        "fr": "Ce moment va passer. Revenez à votre respiration.", "it": "Questo momento passerà. Resta con il tuo respiro.",
        "pl": "Ta chwila minie. Skup się na oddechu.", "tr": "Bu an geçecek. Nefesine odaklan.",
        "ja": "このつらさは過ぎていきます。呼吸に意識を向けましょう。", "ko": "이 순간은 지나갈 거예요. 호흡에 집중해 보세요.",
        "zh-Hans": "这一刻会过去的。把注意力放在呼吸上。",
    },
    "Lung function can improve by up to 30%.": {"uk": "Функція легень може покращитися до 30%."},
}

def protect(text):
    placeholders = re.findall(r"%(?:\d+\$)?[@df]|%%", text)
    for index, value in enumerate(placeholders):
        text = text.replace(value, f"987650{index}012345", 1)
    return text, placeholders

def restore(text, placeholders):
    for index, value in enumerate(placeholders):
        text = text.replace(f"987650{index}012345", value)
    return text

def translate(key, locale):
    if FORMAT_ONLY.match(key):
        return key
    protected, placeholders = protect(key)
    params = urllib.parse.urlencode({
        "client": "gtx", "sl": "en", "tl": API_LOCALE.get(locale, locale),
        "dt": "t", "q": protected,
    })
    request = urllib.request.Request(
        "https://translate.googleapis.com/translate_a/single?" + params,
        headers={"User-Agent": "Mozilla/5.0 BreatheLocalizationAudit/1.0"},
    )
    for attempt in range(4):
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                payload = json.load(response)
            translated = "".join(part[0] for part in payload[0] if part[0])
            translated = restore(translated, placeholders).strip()
            if not translated or sorted(re.findall(r"%(?:\d+\$)?[@df]|%%", translated)) != sorted(placeholders):
                raise ValueError("placeholder mismatch")
            return translated
        except Exception:
            if attempt == 3:
                raise
            time.sleep(1.5 * (attempt + 1))

def translate_batch(keys, locale):
    """Translate several independent UI strings in one request to avoid rate limits."""
    protected = []
    placeholders = []
    for key in keys:
        value, tokens = protect(key)
        protected.append(value)
        placeholders.append(tokens)
    for attempt in range(4):
        try:
            raw = subprocess.check_output([
                "curl", "-fsS", "--get", "https://clients5.google.com/translate_a/t",
                "--data-urlencode", "client=dict-chrome-ex", "--data-urlencode", "sl=en",
                "--data-urlencode", "tl=" + API_LOCALE.get(locale, locale),
                "--data-urlencode", "q=" + ("\n" + BATCH_SEPARATOR + "\n").join(protected),
            ], timeout=35)
            value = json.loads(raw)[0]
            parts = [part.strip() for part in value.split(BATCH_SEPARATOR)]
            if len(parts) != len(keys):
                raise ValueError("translation batch separator mismatch")
            return [restore(part, tokens) for part, tokens in zip(parts, placeholders)]
        except Exception:
            if attempt == 3:
                raise
            time.sleep(3 * (attempt + 1))

def main():
    catalog = json.loads(CATALOG.read_text())
    for key, (english, comment) in SEMANTIC_KEYS.items():
        entry = catalog["strings"].setdefault(key, {})
        entry["comment"] = comment
        entry.setdefault("localizations", {})["en"] = {
            "stringUnit": {"state": "translated", "value": english}
        }
    for key, comment in EXTRA_KEYS.items():
        entry = catalog["strings"].setdefault(key, {})
        entry["comment"] = comment
    for key, comment in GLOSSARY_COMMENTS.items():
        if key in catalog["strings"]:
            catalog["strings"][key]["comment"] = comment
    for key, translations in REVIEWED_OVERRIDES.items():
        entry = catalog["strings"].setdefault(key, {})
        for locale, value in translations.items():
            entry.setdefault("localizations", {})[locale] = {
                "stringUnit": {"state": "translated", "value": value}
            }
    if "--english-only" in sys.argv:
        temporary = CATALOG.with_suffix(".xcstrings.tmp")
        temporary.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n")
        temporary.replace(CATALOG)
        print(f"Catalog English sources updated: {len(catalog['strings'])} keys")
        return
    jobs_by_locale = {locale: [] for locale in LOCALES}
    for key, entry in catalog["strings"].items():
        localizations = entry.setdefault("localizations", {})
        for locale in LOCALES:
            unit = localizations.get(locale, {}).get("stringUnit", {})
            if not unit.get("value"):
                jobs_by_locale[locale].append((key, SEMANTIC_KEYS.get(key, (key, ""))[0]))

    completed = {}
    batches = [(locale, pairs[index:index + 24]) for locale, pairs in jobs_by_locale.items()
               for index in range(0, len(pairs), 24)]
    with ThreadPoolExecutor(max_workers=1) as pool:
        futures = {pool.submit(translate_batch, [source for _, source in pairs], locale): (locale, pairs)
                   for locale, pairs in batches}
        for index, future in enumerate(as_completed(futures), 1):
            locale, pairs = futures[future]
            for (key, _), value in zip(pairs, future.result()):
                completed[(key, locale)] = value
            if index % 10 == 0:
                print(f"Translated {index}/{len(batches)} batches", file=sys.stderr)

    for (key, locale), value in completed.items():
        catalog["strings"][key].setdefault("localizations", {})[locale] = {
            "stringUnit": {"state": "translated", "value": value}
        }

    temporary = CATALOG.with_suffix(".xcstrings.tmp")
    temporary.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n")
    temporary.replace(CATALOG)
    print(f"Catalog complete: {len(catalog['strings'])} keys × {len(LOCALES) + 1} languages")

if __name__ == "__main__":
    main()
