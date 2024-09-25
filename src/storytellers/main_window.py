import asyncio

import numpy as np
from PySide6.QtCore import Qt, QThread, QTimer, Signal, Slot
from PySide6.QtGui import QImage, QPixmap
from PySide6.QtWidgets import QLabel, QMainWindow, QSizePolicy

from . import gen_ai, utils


class AIFrameWorker(QThread):
    frame_ready = Signal(object)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.running = True
        self.frame_index = 1

    def run(self):
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)

        while self.running:
            webcam_frame = utils.get_camera_frame()
            prompt = utils.get_prompt_for_frame(self.frame_index)

            ai_frame = loop.run_until_complete(self.get_ai_frame(webcam_frame, prompt))
            self.frame_ready.emit(ai_frame)
            self.frame_index += 1

    async def get_ai_frame(self, webcam_frame, prompt):
        return await asyncio.to_thread(
            gen_ai.predict,
            webcam_frame,
            prompt,
            utils.NEGATIVE_PROMPT,
            utils.IMAGE_WIDTH,
            utils.AI_STRENGTH,
            1
        )

    def stop(self):
        self.running = False

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Storytellers")
        self.showFullScreen()

        self.image_label = QLabel(self)
        self.image_label.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        self.image_label.setAlignment(Qt.AlignCenter)
        self.setCentralWidget(self.image_label)

        self.frame_index = 1
        self.ai_frame = utils.green_image()

        self.ai_worker = AIFrameWorker()
        self.ai_worker.frame_ready.connect(self.on_ai_frame_ready)
        self.ai_worker.start()

        self.timer = QTimer(self)
        self.timer.timeout.connect(self.update_frame)
        self.timer.start(int(utils.FRAME_TIME * 1000))  # Convert to milliseconds

    @Slot(object)
    def on_ai_frame_ready(self, new_ai_frame):
        self.ai_frame = new_ai_frame

    def update_frame(self):
        film_frame, self.frame_index = utils.get_film_frame(self.frame_index)
        display_frame = utils.chroma_key(film_frame, self.ai_frame)

        # Convert PIL Image to QPixmap and display
        q_image = QImage(np.array(display_frame),
                         display_frame.width,
                         display_frame.height,
                         QImage.Format_RGB888)
        pixmap = QPixmap.fromImage(q_image)

        # Scale the pixmap to fit the label while maintaining aspect ratio
        scaled_pixmap = pixmap.scaled(self.image_label.size(), Qt.KeepAspectRatio, Qt.SmoothTransformation)
        self.image_label.setPixmap(scaled_pixmap)

    def closeEvent(self, event):
        self.ai_worker.stop()
        self.ai_worker.wait()
        utils.cleanup()
        super().closeEvent(event)
