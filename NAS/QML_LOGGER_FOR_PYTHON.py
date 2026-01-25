from PyQt6.QtCore import QtMsgType


#SOS: GOOD LUCK DEBUGGING WITHOUT THIS
def qml_logger(msg_type, context, message):
    """Global handler for QML / Qt debug and error messages."""
    prefix = {
        QtMsgType.QtDebugMsg: "  DEBUG",
        QtMsgType.QtWarningMsg: "  WARNING",
        QtMsgType.QtCriticalMsg: "  CRITICAL",
        QtMsgType.QtFatalMsg: "  FATAL",
        QtMsgType.QtInfoMsg: "  INFO",
    }.get(msg_type, "  LOG")

    log_entry = f"[QML{prefix}] {message}"
    if context.file:
        log_entry += f" (at {context.file}:{context.line})"

    print(log_entry, flush=True)