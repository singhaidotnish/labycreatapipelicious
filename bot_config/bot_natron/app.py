from bot_config.bot_dcc.publish.runners import run_pipeline
PKG = "bot_config.bot_natron"
def launch_publish(context: dict | None = None):
    if context is None:
        context = {"project":"SHOW","seq":"010","shot":"020","task":"comp","version":1,
                   "user":"artist","fps":24.0,"resolution":(1920,1080)}
    run_pipeline(PKG, context)
    return context
