"""Web app: paste a URL, get the dubbed video. Run with: .venv\\Scripts\\python app.py"""
import contextlib
import io
import threading

import gradio as gr

import dub


class _Tee(io.TextIOBase):
    """Captures the pipeline's log lines so the UI can show live progress."""

    def __init__(self, sink):
        self.sink = sink

    def write(self, s):
        self.sink.append(s)
        return len(s)


def run(url, upload, exaggeration, threshold):
    url = upload or url
    if not url or not url.strip():
        raise gr.Error("Paste a video URL or choose a file first.")
    buf, result = [], {}

    def work():
        try:
            with contextlib.redirect_stdout(_Tee(buf)):
                result["file"] = dub.dub(url.strip(), threshold, exaggeration)
        except Exception as e:  # surfaced in the UI below
            result["error"] = e

    t = threading.Thread(target=work)
    t.start()
    while t.is_alive():
        t.join(1.0)
        lines = [l for l in "".join(buf).splitlines() if l.startswith("[dub]")]
        yield None, None, "\n".join(lines[-25:])
    if "error" in result:
        raise gr.Error(str(result["error"]))
    f = str(result["file"])
    lines = [l for l in "".join(buf).splitlines() if l.startswith("[dub]")]
    yield f, f, "\n".join(lines[-25:])


with gr.Blocks(title="Anime Dub") as ui:
    gr.Markdown("# Anime Dub\nPaste a link to a Japanese video. You get it back dubbed in English, "
                "with a separate cloned voice for each character.")
    with gr.Row():
        url = gr.Textbox(label="Video URL", placeholder="https://www.youtube.com/watch?v=...", scale=4)
        go = gr.Button("Dub it", variant="primary", scale=1)
    upload = gr.File(label="...or choose a video file", file_types=["video"], type="filepath")
    with gr.Accordion("Settings", open=False):
        exag = gr.Slider(0.25, 1.0, 0.6, step=0.05, label="Emotion (calm → dramatic)")
        thr = gr.Slider(0.2, 0.6, 0.35, step=0.05, label="Speaker split (low = more separate voices)")
    video = gr.Video(label="Dubbed video")
    file = gr.File(label="Download")
    status = gr.Textbox(label="Progress", lines=12)
    go.click(run, [url, upload, exag, thr], [video, file, status])

if __name__ == "__main__":
    ui.queue().launch(inbrowser=True)
