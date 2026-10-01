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
RELATED_CATALOGS = (Path("Widget/Localizable.xcstrings"), Path("App/Resources/AppShortcuts.xcstrings"))
LOCALES = ("uk", "es", "pt-BR", "de", "fr", "it", "pl", "tr", "ja", "ko", "zh-Hans")
API_LOCALE = {"pt-BR": "pt", "zh-Hans": "zh-CN"}
FORMAT_ONLY = re.compile(r"^(?:%@|%d|%lld|%\.\d+f|%+|/|\s)+$")
BATCH_SEPARATOR = "987654321098765"

def encode_catalog(catalog):
    """Match Xcode's catalog formatting so review diffs stay semantic."""
    return json.dumps(catalog, ensure_ascii=False, indent=2, separators=(",", " : ")) + "\n"
SEMANTIC_KEYS = {
    "onboarding.story.impact.loses": ("Little by little, it can take away:", "Introduces the concrete life areas addiction can affect; keep concise and non-diagnostic."),
    "onboarding.story.impact.sleep": ("Restful sleep", "A concrete life area addiction can take away."),
    "onboarding.story.impact.focus": ("Energy and focus", "A concrete life area addiction can take away."),
    "onboarding.story.impact.people": ("Closeness with people", "A concrete life area addiction can take away."),
    "onboarding.story.impact.resources": ("Time and money", "A concrete life area addiction can take away."),
    "onboarding.story.impact.rest": ("Rest", "Short label for a life area affected by addictive behavior."),
    "onboarding.story.impact.energy": ("Energy", "Short label for a life area affected by addictive behavior."),
    "onboarding.story.impact.connection": ("Connection", "Short label for a life area affected by addictive behavior."),
    "onboarding.story.impact.time": ("Time", "Short label for a life area affected by addictive behavior."),
    "onboarding.story.impact.image.accessibility": ("An open blue landscape with moonlight, sunlight, flowing ribbons, and time dissolving into the sky", "VoiceOver description for the impact illustration."),
    "onboarding.story.freedom.badge": ("Feel freedom", "Short brand promise shown over the full-screen onboarding illustration."),
    "onboarding.story.start_journey": ("Start my journey", "Primary action on the first platform onboarding screen."),
    "onboarding.story.rescue.title": ("Help before the habit takes over", "Value-focused onboarding title without guaranteeing an outcome."),
    "onboarding.story.rescue.detail": ("When you want to smoke, drink, gamble, make an impulse purchase, or keep scrolling, Breathe starts a short guided exercise.", "Concrete examples of the five supported programs and immediate product value."),
    "onboarding.story.rescue.urge": ("You feel pulled toward the habit", "First step in onboarding Rescue demonstration."),
    "onboarding.story.rescue.pause": ("Start a short exercise in Breathe", "Second step in onboarding Rescue demonstration."),
    "onboarding.story.rescue.next": ("You are one step closer to freedom from addiction", "Hopeful final step in the onboarding Rescue demonstration; do not imply a guaranteed outcome."),
    "onboarding.story.rescue.offline": ("Works offline", "Onboarding product attribute."),
    "onboarding.story.rescue.private": ("Private", "Onboarding product attribute."),
    "onboarding.story.rescue.action": ("Create my support plan", "Continue to program selection."),
    "onboarding.story.rescue.disclaimer": ("A self-support tool, not a replacement for professional care.", "Compact product limitation."),
    "onboarding.story.rescue.short_title": ("Pause before the habit takes over", "Short onboarding title about interrupting an automatic habit."),
    "onboarding.story.rescue.short_detail": ("Breathe helps you get through the urge and choose what happens next.", "One-sentence description of immediate support; no guarantee."),
    "onboarding.story.rescue.short_urge": ("The urge appears", "Very short first stage of the Rescue explanation."),
    "onboarding.story.rescue.short_pause": ("Support from Breathe", "Very short second stage describing immediate Breathe support."),
    "onboarding.story.rescue.short_choice": ("One step closer to freedom", "Very short third stage; hopeful without guaranteeing recovery."),
    "onboarding.story.purpose.title": ("Breathe helps you face addiction", "Direct platform purpose without promising treatment or a cure."),
    "onboarding.story.purpose.detail": ("Step by step toward freedom from addiction.", "Short, hopeful explanation without guaranteeing recovery."),
    "onboarding.story.continue": ("Continue", "Continue through the onboarding story."),
    "onboarding.story.impact.title": ("Addiction can take more than it seems", "Short impact title across substance and behavioral programs."),
    "onboarding.story.impact.detail": ("Repeated patterns can affect different parts of everyday life.", "Calm, non-frightening impact explanation."),
    "onboarding.story.impact.health": ("Health and sleep", "Possible area affected by addictive patterns."),
    "onboarding.story.impact.attention": ("Attention and energy", "Possible area affected by addictive patterns."),
    "onboarding.story.impact.relationships": ("Relationships", "Possible area affected by addictive patterns."),
    "onboarding.story.impact.money": ("Money and time", "Possible area affected by addictive patterns."),
    "onboarding.story.impact.qualifier": ("The effects differ by behavior and by person. Breathe does not diagnose them.", "Important qualifier for broad impact claims."),
    "onboarding.story.scale.title": ("Addiction affects millions", "Onboarding statistics title."),
    "onboarding.story.scale.detail": ("You are not alone in wanting change.", "Short human statistics introduction."),
    "onboarding.story.scale.tobacco": ("want to quit tobacco", "WHO 2024 statistic label."),
    "onboarding.story.scale.alcohol": ("live with alcohol use disorders", "WHO 2019 estimate reported in 2024."),
    "onboarding.story.scale.gambling": ("people around one high-risk gambler are affected on average", "WHO global gambling-harm estimate."),
    "onboarding.story.scale.source": ("Sources: World Health Organization, 2024", "Attribution for tobacco, alcohol, and gambling statistics."),
    "onboarding.story.scale.digital": ("young people show problematic smartphone use", "Pooled research estimate; describe problematic use, not a diagnosis."),
    "onboarding.story.scale.spending": ("people show compulsive buying patterns", "Pooled research estimate; do not present as a financial diagnosis."),
    "onboarding.story.scale.gambling_global": ("adults experience gambling-related risk", "Lancet Public Health Commission global estimate; keep the risk qualifier."),
    "onboarding.story.scale.sources_extended": ("Sources: WHO and peer-reviewed meta-analyses, 2016–2024", "Compact attribution for the five statistics shown in onboarding."),
    "onboarding.story.scale.tobacco_short": ("want to quit tobacco", "Very short label paired with the 750M+ statistic."),
    "onboarding.story.scale.alcohol_short": ("alcohol use disorders", "Very short label paired with the 400M statistic."),
    "onboarding.story.scale.digital_short": ("problematic smartphone use", "Very short research label; do not call this a diagnosis."),
    "onboarding.story.scale.spending_short": ("compulsive buying patterns", "Very short research label; do not call this a diagnosis."),
    "onboarding.story.scale.gambling_short": ("at risk of gambling harm", "Very short label that preserves the risk qualifier."),
    "onboarding.story.support.title": ("You do not have to handle every urge alone", "Hopeful transition to Breathe's support."),
    "onboarding.story.support.detail": ("Breathe gives you a private plan for the moments when choice feels harder.", "Honest product role without a guarantee."),
    "onboarding.story.support.notice": ("Notice what triggers the urge", "Breathe support capability."),
    "onboarding.story.support.pause": ("Pause before the impulse becomes an action", "Breathe support capability."),
    "onboarding.story.support.learn": ("Learn which strategies help you", "Breathe support capability; observational, not clinical."),
    "onboarding.story.support.disclaimer": ("Breathe supports change but cannot guarantee recovery or replace professional care.", "Clear limitation and care disclaimer."),
    "onboarding.story.support.action": ("Choose what I want to change", "Move from product story to program selection."),
    "onboarding.checkin.purpose.title": ("Addiction is not the end of your story", "Hopeful platform onboarding title; must not promise a cure."),
    "onboarding.checkin.purpose.detail": ("Breathe helps you regain control: recognize triggers, get through urges, and gradually change the patterns holding you back.", "Clear product purpose without claiming treatment or guaranteed recovery."),
    "onboarding.checkin.welcome.title": ("Let’s understand your difficult moments", "Neutral onboarding welcome title."),
    "onboarding.checkin.welcome.detail": ("Three quick questions. No scores or labels.", "Short onboarding explanation."),
    "onboarding.checkin.welcome.action": ("Begin", "Start the short onboarding questionnaire."),
    "onboarding.checkin.title": ("A quick check-in", "Short questionnaire title."),
    "onboarding.checkin.detail": ("Choose what feels closest right now.", "Short questionnaire guidance."),
    "onboarding.checkin.frequency": ("How often does the impulse show up?", "Questionnaire frequency question."),
    "onboarding.checkin.frequency.rare": ("Rarely", "Impulse frequency answer."),
    "onboarding.checkin.frequency.weekly": ("Some weeks", "Impulse frequency answer."),
    "onboarding.checkin.frequency.daily": ("Daily", "Impulse frequency answer."),
    "onboarding.checkin.frequency.often": ("Many times", "Impulse frequency answer."),
    "onboarding.checkin.intensity": ("How strong does it usually feel?", "Questionnaire intensity question; followed by a labeled 1–5 scale."),
    "onboarding.checkin.period": ("When is it usually hardest?", "Questionnaire time-of-day question."),
    "onboarding.checkin.period.morning": ("Morning", "Time-of-day answer."),
    "onboarding.checkin.period.day": ("Day", "Time-of-day answer."),
    "onboarding.checkin.period.evening": ("Evening", "Time-of-day answer."),
    "onboarding.checkin.period.varies": ("It varies", "Time-of-day answer."),
    "onboarding.checkin.show": ("Show my starting map", "Questionnaire completion action."),
    "onboarding.snapshot.title": ("Your starting map", "Personal onboarding chart title."),
    "onboarding.snapshot.detail": ("A simple view based only on your answers.", "Explains chart data source."),
    "onboarding.snapshot.chart.accessibility": ("Estimated daily pattern based on the frequency, intensity, and time selected", "VoiceOver summary for onboarding chart."),
    "onboarding.snapshot.insight.morning": ("Mornings may deserve a little more preparation.", "Chart interpretation based on selected time."),
    "onboarding.snapshot.insight.day": ("The middle of the day may deserve a little more preparation.", "Chart interpretation based on selected time."),
    "onboarding.snapshot.insight.evening": ("Evenings may deserve a little more preparation.", "Chart interpretation based on selected time."),
    "onboarding.snapshot.insight.varies": ("Your difficult moments vary, so logging context may be useful.", "Chart interpretation based on selected time."),
    "onboarding.snapshot.disclaimer": ("This is not a diagnosis or prediction. It is a starting point you can correct anytime.", "Chart safety disclaimer."),
    "onboarding.snapshot.action": ("Continue", "Finish platform onboarding."),
    "onboarding.chart.morning": ("Morning", "Chart axis label."),
    "onboarding.chart.day": ("Day", "Chart axis label."),
    "onboarding.chart.evening": ("Evening", "Chart axis label."),
    "onboarding.platform.welcome.eyebrow": ("Addiction is not the end of your story", "Hopeful onboarding eyebrow; must not promise a cure."),
    "onboarding.platform.hook.title": ("Take back the moment between urge and action", "Strong but non-judgmental onboarding hook."),
    "onboarding.platform.hook.detail": ("You do not have to change everything today. Breathe helps you pause, regain choice, and take the next step.", "Concise product promise without guaranteeing recovery."),
    "onboarding.platform.hook.action": ("Start taking back control", "Primary onboarding action."),
    "onboarding.platform.support.nicotine.title": ("The craving can pass. Your progress stays.", "Personalized Nicotine onboarding title."),
    "onboarding.platform.support.nicotine.detail": ("When nicotine calls, Breathe gives you a prepared action for the next few minutes.", "Personalized Nicotine support promise."),
    "onboarding.platform.support.digital.title": ("Your phone can wait. Your attention matters.", "Personalized Digital onboarding title."),
    "onboarding.platform.support.digital.detail": ("Breathe helps interrupt automatic checking before another scroll begins.", "Personalized Digital support promise."),
    "onboarding.platform.support.spending.title": ("Not every urge to buy needs a checkout.", "Personalized Spending onboarding title."),
    "onboarding.platform.support.spending.detail": ("Breathe creates time to compare the purchase with what matters more to you.", "Personalized Spending support promise."),
    "onboarding.platform.support.alcohol.title": ("A difficult evening can have a safer plan.", "Personalized Alcohol onboarding title; no treatment claim."),
    "onboarding.platform.support.alcohol.detail": ("Prepare your next step, a safe exit, and someone to contact before the pressure rises.", "Personalized Alcohol support promise."),
    "onboarding.platform.support.gambling.title": ("Put protection between the urge and the bet.", "Personalized Gambling harm-prevention title."),
    "onboarding.platform.support.gambling.detail": ("Breathe helps you delay access, close the app, and reach support before money moves.", "Personalized Gambling support promise."),
    "onboarding.platform.support.moment": ("When a difficult moment arrives", "Personalized support card title."),
    "onboarding.platform.support.pause": ("Pause the automatic reaction", "First concise Breathe support step."),
    "onboarding.platform.support.strategy": ("Try one strategy matched to the moment", "Second concise Breathe support step."),
    "onboarding.platform.support.choice": ("Choose what happens next", "Third concise Breathe support step."),
    "onboarding.platform.support.setback": ("If a setback happens, your progress is not erased. Breathe helps you learn and adjust the plan.", "Non-judgmental setback reassurance."),
    "onboarding.platform.support.action": ("Build my first plan", "Continue to onboarding summary."),
    "onboarding.platform.welcome.title": ("Addiction does not define your future", "Hopeful umbrella onboarding title; must not promise a cure."),
    "onboarding.platform.welcome.detail": ("Breathe helps you notice an urge, create a pause, and choose a next step that supports your goals.", "Platform onboarding introduction."),
    "onboarding.platform.welcome.action": ("Take the first step", "Primary onboarding action."),
    "onboarding.platform.welcome.promise": ("No judgment. No pressure. Support at your pace.", "Supportive onboarding promise."),
    "onboarding.platform.hero.accessibility": ("An open path toward a bright horizon beneath a wide blue sky", "VoiceOver description for the welcome illustration symbolizing freedom."),
    "onboarding.platform.reassurance.title": ("You are not alone", "Onboarding normalization title."),
    "onboarding.platform.reassurance.short_detail": ("Automatic patterns can be understood and changed — one small step at a time.", "Short, program-neutral normalization message."),
    "onboarding.platform.reassurance.detail": ("Patterns can become automatic, especially around stress, routines, or strong emotions. They can also be understood and changed.", "Non-judgmental behavior explanation."),
    "onboarding.platform.stat.title": ("More than 750 million people who use tobacco want to quit", "WHO tobacco statistic; contextual reassurance, not a claim about all programs."),
    "onboarding.platform.stat.detail": ("Many people still lack effective support. Needing help is common — it is not a lack of willpower.", "Interpretation of WHO tobacco support-access statistic."),
    "onboarding.platform.stat.source": ("Source: World Health Organization, 2024", "Attribution for tobacco statistic."),
    "onboarding.platform.not_willpower.title": ("This is not a test of willpower", "Anti-stigma onboarding message."),
    "onboarding.platform.not_willpower.short_detail": ("Prepare a simple next step for difficult moments.", "Short anti-stigma onboarding explanation."),
    "onboarding.platform.not_willpower.detail": ("Breathe helps turn difficult moments into small, practical choices you can prepare for.", "Anti-stigma onboarding explanation."),
    "onboarding.platform.reassurance.action": ("Find my support", "Continue onboarding action."),
    "onboarding.platform.method.title": ("An urge is not a command", "Behavior-change onboarding title."),
    "onboarding.platform.method.detail": ("Breathe supports the moment between an impulse and an action — before, during, and after it happens.", "Description of Breathe's role."),
    "onboarding.platform.method.recognize.title": ("Recognize the pattern", "Breathe Loop benefit title."),
    "onboarding.platform.method.recognize.detail": ("Notice times, triggers, and situations that make an urge more difficult.", "Breathe Loop recognition detail."),
    "onboarding.platform.method.prepare.title": ("Prepare a simple plan", "Breathe Loop benefit title."),
    "onboarding.platform.method.prepare.detail": ("Decide what you will do before a familiar difficult moment arrives.", "Breathe Loop preparation detail."),
    "onboarding.platform.method.respond.title": ("Get help in one tap", "Breathe Loop Rescue benefit title."),
    "onboarding.platform.method.respond.detail": ("Start private, offline Rescue support without answering a long questionnaire.", "Breathe Loop Rescue detail."),
    "onboarding.platform.method.learn.title": ("Learn what helps you", "Breathe Loop learning benefit title."),
    "onboarding.platform.method.learn.detail": ("See careful observations about strategies that helped in similar moments.", "Breathe Loop learning detail; must not imply certainty."),
    "onboarding.platform.ready.title": ("Your support starts with one pause", "Final platform onboarding title."),
    "onboarding.platform.ready.detail": ("You do not have to change everything today. Start by making the next choice a little more intentional.", "Final supportive onboarding message."),
    "onboarding.platform.ready.disclaimer": ("Breathe is a self-support tool. It does not diagnose or replace professional care.", "Scope and medical disclaimer."),
    "onboarding.platform.ready.action": ("Create my plan", "Complete platform onboarding and start selected program."),
    "10 min": ("10 min", "Short waiting-period option."),
    "24 hours": ("24 hours", "Waiting-period option."),
    "72 hours": ("72 hours", "Waiting-period option."),
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
    "onboarding.story.impact.loses": {"uk": "Поступово вона може забирати:"},
    "onboarding.story.impact.sleep": {"uk": "Спокійний сон"},
    "onboarding.story.impact.focus": {"uk": "Енергію та увагу"},
    "onboarding.story.impact.people": {"uk": "Близькість із людьми"},
    "onboarding.story.impact.resources": {"uk": "Час і гроші"},
    "onboarding.story.impact.rest": {"uk": "Спокій"},
    "onboarding.story.impact.energy": {"uk": "Енергія"},
    "onboarding.story.impact.connection": {"uk": "Близькість"},
    "onboarding.story.impact.time": {"uk": "Час"},
    "onboarding.story.impact.image.accessibility": {"uk": "Відкритий блакитний краєвид із місячним і сонячним світлом, повітряними стрічками та часом, що розчиняється в небі"},
    "onboarding.story.freedom.badge": {"uk": "Відчуй свободу"},
    "onboarding.story.start_journey": {"uk": "Почати свій шлях"},
    "onboarding.story.rescue.title": {
        "uk": "Допомога до того, як звичка візьме гору",
        "es": "Breathe está contigo en los momentos difíciles",
        "pt-BR": "Breathe está com você nos momentos difíceis",
        "de": "Breathe ist da, wenn es schwierig wird",
        "fr": "Breathe est là dans les moments difficiles",
        "it": "Breathe è al tuo fianco nei momenti difficili",
        "pl": "Breathe jest z Tobą w trudnych chwilach",
        "tr": "Zor anlarda Breathe yanında",
        "ja": "つらい瞬間も、Breatheが寄り添います",
        "ko": "힘든 순간에도 Breathe가 함께해요",
        "zh-Hans": "艰难时刻，Breathe 陪着你",
    },
    "onboarding.story.rescue.detail": {
        "uk": "Коли хочеться закурити, випити, зробити ставку, купити зайве чи знову відкрити соцмережі, Breathe запускає коротку вправу.",
        "es": "Un toque inicia una breve pausa de apoyo y te propone un siguiente paso claro.",
        "pt-BR": "Um toque inicia uma breve pausa de apoio e mostra um próximo passo claro.",
        "de": "Ein Tippen startet eine kurze unterstützende Pause und zeigt dir einen klaren nächsten Schritt.",
        "fr": "Un geste lance une courte pause guidée et vous propose une prochaine étape claire.",
        "it": "Un tocco avvia una breve pausa guidata e ti propone un passo chiaro.",
        "pl": "Jedno dotknięcie rozpoczyna krótką wspierającą pauzę i podpowiada jasny kolejny krok.",
        "tr": "Tek dokunuşla kısa bir destek molası başlar ve net bir sonraki adım sunulur.",
        "ja": "ワンタップで短いサポートを始め、次の一歩をわかりやすく提案します。",
        "ko": "한 번 탭하면 짧은 도움 세션이 시작되고, 다음 행동을 명확하게 안내해요.",
        "zh-Hans": "轻点一下即可开始短暂的支持引导，并获得清晰的下一步建议。",
    },
    "onboarding.story.rescue.urge": {"uk": "Вас тягне повернутися до звички"},
    "onboarding.story.rescue.pause": {
        "uk": "Запускаєте коротку вправу в Breathe", "es": "Breathe crea una pausa",
        "pt-BR": "Breathe cria uma pausa", "de": "Breathe schafft eine Pause",
        "fr": "Breathe crée une pause", "it": "Breathe crea una pausa",
        "pl": "Breathe tworzy chwilę przerwy", "tr": "Breathe bir mola yaratır",
        "ja": "Breatheが立ち止まる時間をつくる", "ko": "Breathe가 잠시 멈출 틈을 만들어요",
        "zh-Hans": "Breathe 帮你暂停片刻",
    },
    "onboarding.story.rescue.next": {"uk": "Ви на крок ближче до свободи від залежності"},
    "onboarding.story.rescue.offline": {"uk": "Працює офлайн"},
    "onboarding.story.rescue.private": {"uk": "Приватно"},
    "onboarding.story.rescue.action": {"uk": "Створити мій план підтримки"},
    "onboarding.story.rescue.disclaimer": {"uk": "Інструмент самопідтримки, що не замінює професійну допомогу."},
    "onboarding.story.purpose.title": {"uk": "Breathe допомагає долати залежність"},
    "onboarding.story.purpose.detail": {"uk": "Крок за кроком — до свободи від залежності."},
    "onboarding.story.continue": {"uk": "Продовжити"},
    "onboarding.story.impact.title": {"uk": "Залежність забирає більше, ніж здається"},
    "onboarding.story.impact.detail": {"uk": "Повторювані звички можуть торкатися різних сфер повсякденного життя."},
    "onboarding.story.impact.health": {"uk": "Здоров’я та сон"},
    "onboarding.story.impact.attention": {"uk": "Увага та енергія"},
    "onboarding.story.impact.relationships": {"uk": "Стосунки"},
    "onboarding.story.impact.money": {"uk": "Гроші та час"},
    "onboarding.story.impact.qualifier": {"uk": "Вплив залежить від поведінки й конкретної людини. Breathe не встановлює діагнозів."},
    "onboarding.story.scale.title": {"uk": "Залежність стосується мільйонів"},
    "onboarding.story.scale.detail": {"uk": "Ви не самі у своєму прагненні змін."},
    "onboarding.story.scale.tobacco": {
        "uk": "хочуть відмовитися від тютюну",
        "es": "personas que consumen tabaco quieren dejarlo", "pt-BR": "pessoas que usam tabaco querem parar",
        "de": "Menschen, die Tabak konsumieren, möchten aufhören", "fr": "de personnes consommant du tabac souhaitent arrêter",
        "it": "persone che usano tabacco vogliono smettere", "pl": "osób używających tytoniu chce z niego zrezygnować",
        "tr": "tütün kullanan kişi bırakmak istiyor", "ja": "人以上のたばこ使用者が禁煙を望んでいます",
        "ko": "명 이상의 담배 사용자가 금연을 원합니다", "zh-Hans": "烟草使用者希望戒烟",
    },
    "onboarding.story.scale.alcohol": {"uk": "живуть із розладами, пов’язаними з уживанням алкоголю"},
    "onboarding.story.scale.gambling": {
        "uk": "близьких у середньому відчувають наслідки ризикованої гри однієї людини",
        "es": "personas más se ven afectadas, en promedio, por cada persona que juega a niveles de alto riesgo",
        "pt-BR": "outras pessoas são afetadas, em média, por cada pessoa que joga em níveis de alto risco",
        "de": "weitere Menschen sind im Durchschnitt von jeder Person betroffen, die auf hohem Risikoniveau spielt",
        "fr": "autres personnes sont touchées en moyenne par chaque personne qui joue à un niveau à haut risque",
        "it": "altre persone subiscono in media conseguenze per ogni persona che gioca a livelli ad alto rischio",
        "pl": "innych osób średnio odczuwa skutki zachowania jednej osoby grającej na poziomie wysokiego ryzyka",
        "tr": "kişi, yüksek risk düzeyinde kumar oynayan her bir kişiden ortalama olarak etkileniyor",
        "ja": "人が、ハイリスクなギャンブルをする1人の影響を平均して受けています",
        "ko": "명이 고위험 수준으로 도박하는 한 사람의 영향을 평균적으로 받습니다",
        "zh-Hans": "人平均会受到一名高风险赌博者的影响",
    },
    "onboarding.story.scale.source": {"uk": "Джерела: Всесвітня організація охорони здоров’я, 2024"},
    "onboarding.story.support.title": {"uk": "Не обов’язково проходити кожен імпульс наодинці"},
    "onboarding.story.support.detail": {"uk": "Breathe дає приватний план для моментів, коли робити вибір стає складніше."},
    "onboarding.story.support.notice": {"uk": "Помічайте, що запускає імпульс"},
    "onboarding.story.support.pause": {"uk": "Зробіть паузу до того, як імпульс стане дією"},
    "onboarding.story.support.learn": {"uk": "Дізнавайтеся, які стратегії допомагають саме вам"},
    "onboarding.story.support.disclaimer": {"uk": "Breathe підтримує зміни, але не гарантує одужання й не замінює професійну допомогу."},
    "onboarding.story.support.action": {"uk": "Обрати, що я хочу змінити"},
    "onboarding.checkin.purpose.title": {"uk": "Залежність — не кінець вашої історії"},
    "onboarding.checkin.purpose.detail": {
        "uk": "Breathe допомагає повертати контроль: помічати тригери, проходити крізь імпульси й поступово змінювати звички, що вас стримують.",
        "es": "Breathe te ayuda a recuperar el control: reconocer los desencadenantes, atravesar los impulsos y cambiar poco a poco los patrones que te frenan.",
        "pt-BR": "O Breathe ajuda você a retomar o controle: reconhecer gatilhos, atravessar os impulsos e mudar aos poucos os padrões que limitam você.",
        "de": "Breathe hilft dir, die Kontrolle zurückzugewinnen: Auslöser zu erkennen, Impulse zu überstehen und hinderliche Muster schrittweise zu verändern.",
        "fr": "Breathe vous aide à reprendre le contrôle : repérer les déclencheurs, traverser les envies et changer progressivement les habitudes qui vous freinent.",
        "it": "Breathe ti aiuta a riprendere il controllo: riconoscere i fattori scatenanti, superare gli impulsi e cambiare gradualmente gli schemi che ti ostacolano.",
        "pl": "Breathe pomaga odzyskać kontrolę: rozpoznawać wyzwalacze, przechodzić przez impulsy i stopniowo zmieniać nawyki, które Cię ograniczają.",
        "tr": "Breathe kontrolü yeniden kazanmanıza yardımcı olur: tetikleyicileri fark edin, dürtüleri atlatın ve sizi kısıtlayan alışkanlıkları adım adım değiştirin.",
        "ja": "Breatheは、きっかけに気づき、衝動をやり過ごし、自分を縛る習慣を少しずつ変えることで、主導権を取り戻すお手伝いをします。",
        "ko": "Breathe는 유발 요인을 알아차리고 충동을 넘긴 뒤, 나를 붙잡는 습관을 조금씩 바꾸며 주도권을 되찾도록 도와줍니다.",
        "zh-Hans": "Breathe 帮助你重新掌握主动：觉察诱因、度过冲动，并逐步改变束缚自己的习惯模式。",
    },
    "onboarding.checkin.welcome.title": {"uk": "Зрозуміймо ваші складні моменти"},
    "onboarding.checkin.welcome.detail": {"uk": "Три короткі запитання. Без оцінок і ярликів."},
    "onboarding.checkin.welcome.action": {"uk": "Почати"},
    "onboarding.checkin.title": {"uk": "Коротке опитування"},
    "onboarding.checkin.detail": {"uk": "Оберіть те, що зараз найближче до вашого досвіду."},
    "onboarding.checkin.frequency": {"uk": "Як часто виникає імпульс?"},
    "onboarding.checkin.frequency.rare": {"uk": "Рідко"},
    "onboarding.checkin.frequency.weekly": {"uk": "Іноді"},
    "onboarding.checkin.frequency.daily": {"uk": "Щодня"},
    "onboarding.checkin.frequency.often": {"uk": "Багато разів"},
    "onboarding.checkin.intensity": {"uk": "Наскільки сильним він зазвичай буває?"},
    "onboarding.checkin.period": {"uk": "Коли зазвичай найскладніше?"},
    "onboarding.checkin.period.morning": {"uk": "Вранці"},
    "onboarding.checkin.period.day": {"uk": "Удень"},
    "onboarding.checkin.period.evening": {"uk": "Увечері"},
    "onboarding.checkin.period.varies": {"uk": "По-різному"},
    "onboarding.checkin.show": {"uk": "Показати стартову карту"},
    "onboarding.snapshot.title": {"uk": "Ваша стартова карта"},
    "onboarding.snapshot.detail": {"uk": "Проста візуалізація лише на основі ваших відповідей."},
    "onboarding.snapshot.chart.accessibility": {"uk": "Орієнтовна зміна складності протягом дня на основі обраних частоти, сили й часу"},
    "onboarding.snapshot.insight.morning": {"uk": "Вранці може знадобитися трохи більше підготовки."},
    "onboarding.snapshot.insight.day": {"uk": "У середині дня може знадобитися трохи більше підготовки."},
    "onboarding.snapshot.insight.evening": {"uk": "Увечері може знадобитися трохи більше підготовки."},
    "onboarding.snapshot.insight.varies": {"uk": "Складні моменти виникають у різний час, тому корисно фіксувати контекст."},
    "onboarding.snapshot.disclaimer": {"uk": "Це не діагноз і не прогноз, а стартова точка, яку можна будь-коли уточнити."},
    "onboarding.snapshot.action": {"uk": "Продовжити"},
    "onboarding.chart.morning": {"uk": "Ранок"},
    "onboarding.chart.day": {"uk": "День"},
    "onboarding.chart.evening": {"uk": "Вечір"},
    "onboarding.platform.welcome.eyebrow": {"uk": "Залежність — не кінець вашої історії"},
    "onboarding.platform.hook.title": {"uk": "Поверніть собі мить між імпульсом і дією"},
    "onboarding.platform.hook.detail": {"uk": "Не потрібно змінювати все сьогодні. Breathe допоможе зупинитися, повернути вибір і зробити наступний крок."},
    "onboarding.platform.hook.action": {"uk": "Почати повертати контроль"},
    "onboarding.platform.support.nicotine.title": {"uk": "Тяга мине. Ваш прогрес залишиться."},
    "onboarding.platform.support.nicotine.detail": {"uk": "Коли тягне до нікотину, Breathe запропонує підготовлену дію на найближчі кілька хвилин."},
    "onboarding.platform.support.digital.title": {"uk": "Телефон зачекає. Ваша увага важлива."},
    "onboarding.platform.support.digital.detail": {"uk": "Breathe допоможе перервати автоматичну перевірку ще до початку чергового гортання."},
    "onboarding.platform.support.spending.title": {"uk": "Не кожен імпульс купити має завершуватися оплатою."},
    "onboarding.platform.support.spending.detail": {"uk": "Breathe дасть час порівняти покупку з тим, що для вас важливіше."},
    "onboarding.platform.support.alcohol.title": {"uk": "Для складного вечора можна підготувати безпечніший план."},
    "onboarding.platform.support.alcohol.detail": {"uk": "Заздалегідь оберіть наступний крок, безпечний вихід із ситуації та людину, якій можна написати."},
    "onboarding.platform.support.gambling.title": {"uk": "Поставте захист між імпульсом і ставкою."},
    "onboarding.platform.support.gambling.detail": {"uk": "Breathe допоможе відкласти доступ, закрити застосунок і звернутися по підтримку до переказу грошей."},
    "onboarding.platform.support.moment": {"uk": "Коли настає складний момент"},
    "onboarding.platform.support.pause": {"uk": "Зупиніть автоматичну реакцію"},
    "onboarding.platform.support.strategy": {"uk": "Спробуйте одну доречну стратегію"},
    "onboarding.platform.support.choice": {"uk": "Оберіть, що буде далі"},
    "onboarding.platform.support.setback": {"uk": "Якщо станеться зрив, ваш прогрес не зникне. Breathe допоможе зробити висновок і скоригувати план."},
    "onboarding.platform.support.action": {"uk": "Створити мій перший план"},
    "onboarding.platform.welcome.title": {"uk": "Залежність — не вирок"},
    "onboarding.platform.welcome.detail": {"uk": "Breathe допоможе помітити імпульс, зробити паузу й обрати наступний крок, що відповідає вашим цілям."},
    "onboarding.platform.welcome.action": {"uk": "Зробити перший крок"},
    "onboarding.platform.welcome.promise": {"uk": "Без осуду. Без тиску. У зручному для вас темпі."},
    "onboarding.platform.hero.accessibility": {
        "uk": "Відкритий шлях до світлого горизонту під безкраїм блакитним небом",
        "es": "Un camino abierto hacia un horizonte luminoso bajo un amplio cielo azul",
        "pt-BR": "Um caminho aberto rumo a um horizonte luminoso sob um vasto céu azul",
        "de": "Ein offener Weg zu einem hellen Horizont unter einem weiten blauen Himmel",
        "fr": "Un chemin ouvert vers un horizon lumineux sous un vaste ciel bleu",
        "it": "Un sentiero aperto verso un orizzonte luminoso sotto un ampio cielo azzurro",
        "pl": "Otwarta droga ku jasnemu horyzontowi pod rozległym błękitnym niebem",
        "tr": "Geniş mavi bir gökyüzünün altında aydınlık ufka uzanan açık bir yol",
        "ja": "広い青空の下、明るい地平線へと続く開かれた道",
        "ko": "넓고 푸른 하늘 아래 밝은 지평선으로 이어지는 열린 길",
        "zh-Hans": "广阔蓝天下，一条通往明亮地平线的开阔道路",
    },
    "onboarding.platform.reassurance.title": {"uk": "Ви не самі"},
    "onboarding.platform.reassurance.short_detail": {"uk": "Автоматичні звички можна зрозуміти й поступово змінити — крок за кроком."},
    "onboarding.platform.reassurance.detail": {"uk": "Поведінка може ставати автоматичною, особливо під час стресу, звичних ситуацій або сильних емоцій. Її можна краще зрозуміти й поступово змінити."},
    "onboarding.platform.stat.title": {"uk": "Понад 750 мільйонів людей, які вживають тютюн, хочуть відмовитися від нього"},
    "onboarding.platform.stat.detail": {"uk": "Багатьом досі бракує дієвої підтримки. Потребувати допомоги — нормально, і це не свідчить про брак сили волі."},
    "onboarding.platform.stat.source": {"uk": "Джерело: Всесвітня організація охорони здоров’я, 2024"},
    "onboarding.platform.not_willpower.title": {"uk": "Це не випробування сили волі"},
    "onboarding.platform.not_willpower.short_detail": {"uk": "Підготуйте простий наступний крок для складних моментів."},
    "onboarding.platform.not_willpower.detail": {"uk": "Breathe допомагає перетворити складні моменти на невеликі практичні кроки, до яких можна підготуватися."},
    "onboarding.platform.reassurance.action": {"uk": "Знайти свою опору"},
    "onboarding.platform.method.title": {"uk": "Імпульс — це не команда"},
    "onboarding.platform.method.detail": {"uk": "Breathe підтримує в момент між імпульсом і дією — до, під час і після складної ситуації."},
    "onboarding.platform.method.recognize.title": {"uk": "Помічайте закономірності"},
    "onboarding.platform.method.recognize.detail": {"uk": "Відстежуйте час, тригери й ситуації, у яких імпульс стає сильнішим."},
    "onboarding.platform.method.prepare.title": {"uk": "Підготуйте простий план"},
    "onboarding.platform.method.prepare.detail": {"uk": "Заздалегідь вирішіть, що зробите, коли настане знайомий складний момент."},
    "onboarding.platform.method.respond.title": {"uk": "Отримайте допомогу одним дотиком"},
    "onboarding.platform.method.respond.detail": {"uk": "Запустіть приватну офлайн-підтримку Rescue без довгих анкет."},
    "onboarding.platform.method.learn.title": {"uk": "Дізнавайтеся, що допомагає саме вам"},
    "onboarding.platform.method.learn.detail": {"uk": "Переглядайте обережні спостереження про стратегії, що допомагали в подібних ситуаціях."},
    "onboarding.platform.ready.title": {"uk": "Ваша підтримка починається з однієї паузи"},
    "onboarding.platform.ready.detail": {"uk": "Не потрібно змінювати все сьогодні. Почніть із трохи більш усвідомленого наступного вибору."},
    "onboarding.platform.ready.disclaimer": {"uk": "Breathe — інструмент самопідтримки. Він не встановлює діагнозів і не замінює професійну допомогу."},
    "onboarding.platform.ready.action": {"uk": "Створити мій план"},
    "onboarding.platform.welcome.detail": {
        "tr": "Breathe, dürtüyü fark etmenize, kısa bir ara vermenize ve hedeflerinizi destekleyen bir sonraki adımı seçmenize yardımcı olur.",
        "ja": "Breatheは、衝動に気づいてひと呼吸置き、自分の目標に沿った次の行動を選ぶお手伝いをします。",
        "ko": "Breathe는 충동을 알아차리고 잠시 멈춘 뒤, 목표에 맞는 다음 행동을 선택하도록 도와줍니다.",
        "zh-Hans": "Breathe 帮助你觉察冲动、留出片刻停顿，并选择更符合目标的下一步。",
    },
    "onboarding.platform.not_willpower.detail": {
        "tr": "Breathe, zor anları önceden hazırlanabileceğiniz küçük ve uygulanabilir adımlara dönüştürmenize yardımcı olur.",
        "ja": "Breatheは、難しい瞬間を、あらかじめ備えられる小さく具体的な選択へと変えるお手伝いをします。",
        "ko": "Breathe는 힘든 순간을 미리 준비할 수 있는 작고 실천 가능한 선택으로 바꾸도록 도와줍니다.",
        "zh-Hans": "Breathe 帮助你把困难时刻转化为可以提前准备的、具体而微小的选择。",
    },
    "onboarding.platform.method.detail": {
        "ja": "Breatheは、衝動から行動に移るまでの間を支えます。難しい瞬間の前も、最中も、その後も寄り添います。",
        "ko": "Breathe는 충동이 행동으로 이어지기 전의 순간을 돕습니다. 힘든 순간의 전과 도중, 이후까지 함께합니다.",
        "zh-Hans": "Breathe 在冲动与行动之间提供支持，也陪你应对困难时刻的之前、当下与之后。",
    },
    "onboarding.platform.method.title": {"zh-Hans": "冲动不是命令"},
    "onboarding.platform.ready.disclaimer": {
        "tr": "Breathe bir öz destek aracıdır. Tanı koymaz ve profesyonel bakımın yerini tutmaz.",
        "ja": "Breatheはセルフサポートのためのツールです。診断を行うものではなく、専門家による支援の代わりにはなりません。",
        "ko": "Breathe는 스스로를 돕기 위한 도구입니다. 진단을 내리거나 전문적인 치료를 대신하지 않습니다.",
        "zh-Hans": "Breathe 是一款自助工具，不能用于诊断，也不能替代专业帮助。",
    },
    "10 min": {
        "uk": "10 хв", "es": "10 minutos", "pt-BR": "10 minutos", "de": "10 Min.", "fr": "10 minutes",
        "it": "10 minuti", "pl": "10 minut", "tr": "10 dk.", "ja": "10分", "ko": "10분", "zh-Hans": "10 分钟",
    },
    "24 hours": {
        "uk": "24 години", "es": "24 horas", "pt-BR": "24 horas", "de": "24 Stunden", "fr": "24 heures",
        "it": "24 ore", "pl": "24 godziny", "tr": "24 saat", "ja": "24時間", "ko": "24시간", "zh-Hans": "24 小时",
    },
    "72 hours": {
        "uk": "72 години", "es": "72 horas", "pt-BR": "72 horas", "de": "72 Stunden", "fr": "72 heures",
        "it": "72 ore", "pl": "72 godziny", "tr": "72 saat", "ja": "72時間", "ko": "72시간", "zh-Hans": "72 小时",
    },
    # Product names keep the umbrella brand untranslated. Translating "Breathe"
    # as a verb produced unsafe nonsense such as "inhale nicotine".
    "program.nicotine.name": {locale: "Breathe Nicotine" for locale in LOCALES},
    "program.digital.name": {locale: "Breathe Digital" for locale in LOCALES},
    "program.spending.name": {locale: "Breathe Spending" for locale in LOCALES},
    "program.alcohol.name": {locale: "Breathe Alcohol" for locale in LOCALES},
    "program.gambling.name": {locale: "Breathe Gambling" for locale in LOCALES},
    "brand.regain_control": {
        "uk": "Повертайте контроль — крок за кроком.", "es": "Recupera el control, impulso a impulso.",
        "pt-BR": "Retome o controle, um impulso de cada vez.", "de": "Gewinne Schritt für Schritt die Kontrolle zurück.",
        "fr": "Reprenez le contrôle, une envie à la fois.", "it": "Riprendi il controllo, un impulso alla volta.",
        "pl": "Odzyskuj kontrolę — krok po kroku.", "tr": "Kontrolü adım adım geri kazanın.",
        "ja": "衝動と一つずつ向き合い、自分らしい選択を。", "ko": "충동을 하나씩 넘기며 주도권을 되찾으세요.",
        "zh-Hans": "一次应对一个冲动，逐步重拾掌控。",
    },
    "program.alcohol.description": {
        "uk": "Спостерігайте за вживанням алкоголю та безпечно готуйтеся до складних ситуацій.",
        "es": "Reflexiona sobre tu consumo de alcohol y prepárate con seguridad para situaciones difíciles.",
        "pt-BR": "Reflita sobre o consumo de álcool e prepare-se com segurança para situações difíceis.",
        "de": "Beobachte deinen Alkoholkonsum und bereite dich sicher auf schwierige Situationen vor.",
        "fr": "Faites le point sur votre consommation d’alcool et préparez-vous en toute sécurité aux situations difficiles.",
        "it": "Rifletti sul consumo di alcol e preparati in sicurezza alle situazioni difficili.",
        "pl": "Przyjrzyj się swojemu piciu i bezpiecznie przygotuj się na trudne sytuacje.",
        "tr": "Alkol kullanımınızı gözden geçirin ve zor durumlara güvenli biçimde hazırlanın.",
        "ja": "飲酒習慣を振り返り、難しい状況に安全に備えましょう。",
        "ko": "음주 습관을 돌아보고 어려운 상황에 안전하게 대비하세요.",
        "zh-Hans": "审视自己的饮酒情况，安全地为困难时刻做好准备。",
    },
    "rescue.reflect.detail": {
        "uk": "Це був складний момент. Усе, чого ви навчилися й досягли, залишається важливим.",
        "es": "Ha sido un momento difícil. Lo que has aprendido y logrado sigue importando.",
        "pt-BR": "Foi um momento difícil. Tudo o que você aprendeu e conquistou continua valendo.",
        "de": "Das war ein schwieriger Moment. Was du gelernt und erreicht hast, zählt weiterhin.",
        "fr": "Ce moment a été difficile. Ce que vous avez appris et accompli compte toujours.",
        "it": "È stato un momento difficile. Ciò che hai imparato e raggiunto conta ancora.",
        "pl": "To był trudny moment. To, czego się nauczyłeś i co osiągnąłeś, nadal ma znaczenie.",
        "tr": "Bu zor bir andı. Öğrendikleriniz ve başardıklarınız hâlâ önemli.",
        "ja": "つらい瞬間でした。それでも、これまでの学びや歩みが失われることはありません。",
        "ko": "힘든 순간이었어요. 지금까지 배우고 이룬 것들은 여전히 소중합니다.",
        "zh-Hans": "刚才是个艰难的时刻，但你的收获和进步依然重要。",
    },
    "spending.pause_list.title": {
        "uk": "Список відкладених покупок", "es": "Lista para decidir después", "pt-BR": "Lista para decidir depois",
        "de": "Später-entscheiden-Liste", "fr": "Liste de réflexion", "it": "Lista per decidere dopo",
        "pl": "Lista odłożonych zakupów", "tr": "Bekletme Listesi", "ja": "保留リスト", "ko": "구매 보류 목록", "zh-Hans": "暂缓购买清单",
    },
    "strategy.urge_surf.title": {
        "uk": "Перечекати хвилю", "es": "Deja pasar la ola", "pt-BR": "Deixe a onda passar",
        "de": "Die Welle vorbeiziehen lassen", "fr": "Laisser passer la vague", "it": "Lascia passare l’onda",
        "pl": "Pozwól fali minąć", "tr": "Dalganın geçmesine izin ver", "ja": "衝動の波をやり過ごす",
        "ko": "충동의 파도 흘려보내기", "zh-Hans": "让冲动的浪潮过去",
    },
    "strategy.remove_card.title": {
        "uk": "Ускладнити оплату", "es": "Pon una barrera al pago", "pt-BR": "Crie uma barreira para o pagamento",
        "de": "Eine Zahlungshürde einbauen", "fr": "Ajouter un frein au paiement", "it": "Aggiungi un ostacolo al pagamento",
        "pl": "Utrudnij dokonanie płatności", "tr": "Ödemeyi zorlaştırın", "ja": "支払いまでにひと手間加える",
        "ko": "결제에 한 단계 더 두기", "zh-Hans": "为付款增加一道阻力",
    },
    "alcohol.safety.detail": {
        "uk": "Для деяких людей різка відмова від алкоголю може бути небезпечною. Ці запитання допоможуть Breathe показати доречну інформацію про безпеку, але не є діагностикою.",
        "es": "Para algunas personas, dejar el alcohol de golpe puede ser peligroso. Estas preguntas ayudan a Breathe a mostrar información de seguridad adecuada, pero no constituyen un diagnóstico.",
        "pt-BR": "Para algumas pessoas, parar de beber de repente pode ser perigoso. Estas perguntas ajudam o Breathe a mostrar orientações de segurança adequadas, mas não fazem um diagnóstico.",
        "de": "Für manche Menschen kann es gefährlich sein, plötzlich mit dem Alkohol aufzuhören. Diese Fragen helfen Breathe, passende Sicherheitshinweise anzuzeigen; sie ersetzen keine Diagnose.",
        "fr": "Pour certaines personnes, arrêter brusquement l’alcool peut être dangereux. Ces questions aident Breathe à afficher des informations de sécurité adaptées, mais ne constituent pas un diagnostic.",
        "it": "Per alcune persone interrompere bruscamente il consumo di alcol può essere pericoloso. Queste domande aiutano Breathe a mostrare indicazioni di sicurezza adeguate, ma non costituiscono una diagnosi.",
        "pl": "Dla niektórych osób nagłe odstawienie alkoholu może być niebezpieczne. Te pytania pomogą Breathe wyświetlić odpowiednie informacje dotyczące bezpieczeństwa, ale nie służą do stawiania diagnozy.",
        "tr": "Bazı kişiler için alkolü aniden bırakmak tehlikeli olabilir. Bu sorular Breathe’in uygun güvenlik bilgilerini göstermesine yardımcı olur; tanı koymaz.",
        "ja": "人によっては、急に断酒すると危険な場合があります。これらの質問は、Breatheが適切な安全情報を表示するためのもので、診断を行うものではありません。",
        "ko": "일부 사람에게는 갑자기 술을 끊는 것이 위험할 수 있습니다. 이 질문은 Breathe가 알맞은 안전 정보를 안내하는 데 사용되며, 진단을 위한 것이 아닙니다.",
        "zh-Hans": "对有些人来说，突然停止饮酒可能会有危险。这些问题仅用于帮助 Breathe 提供适当的安全信息，并非医学诊断。",
    },
    "alcohol.safety.warning": {
        "uk": "Не намагайтеся різко припинити вживання алкоголю без фахової підтримки. Зверніться до кваліфікованого медичного працівника. Сильне тремтіння, судоми, галюцинації чи сплутаність свідомості потребують невідкладної медичної допомоги.",
        "es": "No intentes dejar el alcohol de golpe sin apoyo profesional. Contacta con un profesional sanitario cualificado. Los temblores intensos, las convulsiones, las alucinaciones o la confusión requieren atención médica urgente.",
        "pt-BR": "Não tente parar de beber de repente sem apoio profissional. Procure um profissional de saúde qualificado. Tremores intensos, convulsões, alucinações ou confusão exigem atendimento médico de emergência.",
        "de": "Versuche nicht, ohne fachliche Unterstützung abrupt mit dem Alkohol aufzuhören. Wende dich an medizinisches Fachpersonal. Starkes Zittern, Krampfanfälle, Halluzinationen oder Verwirrtheit erfordern sofortige medizinische Hilfe.",
        "fr": "N’essayez pas d’arrêter brusquement l’alcool sans accompagnement professionnel. Contactez un professionnel de santé qualifié. Des tremblements importants, des convulsions, des hallucinations ou une confusion nécessitent des soins médicaux urgents.",
        "it": "Non interrompere bruscamente il consumo di alcol senza assistenza professionale. Contatta un professionista sanitario qualificato. Tremori intensi, convulsioni, allucinazioni o stato confusionale richiedono assistenza medica urgente.",
        "pl": "Nie odstawiaj alkoholu nagle bez fachowego wsparcia. Skontaktuj się z wykwalifikowanym pracownikiem ochrony zdrowia. Silne drżenie, drgawki, omamy lub dezorientacja wymagają pilnej pomocy medycznej.",
        "tr": "Uzman desteği olmadan alkolü aniden bırakmaya çalışmayın. Yetkin bir sağlık uzmanına başvurun. Şiddetli titreme, nöbet, halüsinasyon veya bilinç bulanıklığı acil tıbbi yardım gerektirir.",
        "ja": "専門家の支援なしに急な断酒をしないでください。資格を持つ医療従事者に相談してください。激しい震え、けいれん、幻覚、意識の混乱がある場合は、緊急の医療処置が必要です。",
        "ko": "전문가의 도움 없이 갑자기 술을 끊으려 하지 마세요. 자격을 갖춘 의료 전문가와 상담하세요. 심한 떨림, 발작, 환각 또는 의식 혼란이 나타나면 즉시 응급 진료를 받아야 합니다.",
        "zh-Hans": "请勿在没有专业支持的情况下突然停止饮酒。请联系合格的医疗专业人员。严重发抖、抽搐、幻觉或意识混乱需要立即接受急诊救治。",
    },
    "gambling.safety.warning": {
        "uk": "Ви заслуговуєте на негайну підтримку небайдужої людини. Просто зараз зверніться до місцевої екстреної або кризової служби чи до людини, якій довіряєте.",
        "es": "Mereces recibir apoyo humano de inmediato. Contacta ahora con los servicios locales de emergencias o de atención en crisis, o con alguien de confianza.",
        "pt-BR": "Você merece apoio humano imediato. Entre em contato agora com um serviço local de emergência ou apoio em crise, ou com alguém de confiança.",
        "de": "Du verdienst jetzt direkte Unterstützung. Wende dich sofort an einen örtlichen Notfall- oder Krisendienst oder an eine vertraute Person.",
        "fr": "Vous méritez un soutien humain immédiat. Contactez dès maintenant les services d’urgence ou d’aide en situation de crise de votre région, ou une personne de confiance.",
        "it": "Meriti subito il sostegno di una persona. Contatta ora i servizi locali di emergenza o di supporto nelle crisi, oppure una persona di fiducia.",
        "pl": "Zasługujesz na natychmiastowe wsparcie drugiej osoby. Skontaktuj się teraz z lokalnymi służbami ratunkowymi, ośrodkiem interwencji kryzysowej lub zaufaną osobą.",
        "tr": "Şu anda doğrudan insan desteğini hak ediyorsunuz. Hemen yerel acil yardım veya kriz destek hizmetleriyle ya da güvendiğiniz biriyle iletişime geçin.",
        "ja": "今すぐ人の支援を受けてください。地域の緊急窓口や相談窓口、または信頼できる人に、今すぐ連絡してください。",
        "ko": "지금 바로 사람의 도움을 받을 자격이 있습니다. 지역 응급·위기 지원 기관이나 믿을 수 있는 사람에게 즉시 연락하세요.",
        "zh-Hans": "你值得立即获得他人的支持。请马上联系当地急救或危机援助服务，或联系你信任的人。",
    },
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
        temporary.write_text(encode_catalog(catalog))
        temporary.replace(CATALOG)
        for related_path in RELATED_CATALOGS:
            if not related_path.exists():
                continue
            related = json.loads(related_path.read_text())
            changed = False
            for key, translations in REVIEWED_OVERRIDES.items():
                if key not in related.get("strings", {}):
                    continue
                for locale, value in translations.items():
                    related["strings"][key].setdefault("localizations", {})[locale] = {
                        "stringUnit": {"state": "translated", "value": value}
                    }
                    changed = True
            if changed:
                output = related_path.with_suffix(".xcstrings.tmp")
                output.write_text(encode_catalog(related))
                output.replace(related_path)
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
    temporary.write_text(encode_catalog(catalog))
    temporary.replace(CATALOG)
    # Keep shared reviewed copy consistent in extensions without adding keys
    # that do not belong to those targets.
    for related_path in RELATED_CATALOGS:
        if not related_path.exists():
            continue
        related = json.loads(related_path.read_text())
        changed = False
        for key, translations in REVIEWED_OVERRIDES.items():
            if key not in related.get("strings", {}):
                continue
            for locale, value in translations.items():
                related["strings"][key].setdefault("localizations", {})[locale] = {
                    "stringUnit": {"state": "translated", "value": value}
                }
                changed = True
        if changed:
            output = related_path.with_suffix(".xcstrings.tmp")
            output.write_text(encode_catalog(related))
            output.replace(related_path)
    print(f"Catalog complete: {len(catalog['strings'])} keys × {len(LOCALES) + 1} languages")

if __name__ == "__main__":
    main()
