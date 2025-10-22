class VideoPlayerWithBBox {
  constructor() {
    this.video = document.getElementById('videoPlayer');
    this.canvas = document.getElementById('bboxCanvas');
    
    if (!this.video || !this.canvas) {
      console.error('Video player or canvas not found');
      return;
    }
    
    this.ctx = this.canvas.getContext('2d');
    this.videoId = this.video.dataset.videoId;
    
    this.framesData = {};
    this.currentFrame = 0;
    this.fps = 30; // 動画のFPS（解析時のFPSに合わせる）
    this.showBbox = true;
    this.showLabels = true;
    this.isPlaying = false;
    
    this.colors = ['#00ff00', '#ff0000', '#0000ff', '#ffff00', '#ff00ff', '#00ffff'];
    
    this.init();
  }
  
  async init() {
    // 動画サイズに合わせてキャンバスを設定
    this.video.addEventListener('loadedmetadata', () => {
      this.resizeCanvas();
    });
    
    // ウィンドウサイズ変更時にキャンバスをリサイズ
    window.addEventListener('resize', () => {
      this.resizeCanvas();
    });
    
    // 全フレームの検出データを読み込み
    await this.loadAllFramesData();
    
    // 各種イベント登録
    this.setupEventListeners();
    
    // 初期描画
    this.updateCanvas();
  }
  
  resizeCanvas() {
    const rect = this.video.getBoundingClientRect();
    this.canvas.width = rect.width;
    this.canvas.height = rect.height;
    
    this.videoWidth = this.video.videoWidth;
    this.videoHeight = this.video.videoHeight;
    
    this.scaleX = rect.width / this.videoWidth;
    this.scaleY = rect.height / this.videoHeight;
    
    console.log(`Canvas resized: ${rect.width}x${rect.height}, Scale: ${this.scaleX.toFixed(2)}x${this.scaleY.toFixed(2)}`);
    
    this.updateCanvas();
  }
  
  async loadAllFramesData() {
    try {
      const response = await fetch(`/videos/${this.videoId}/all_frames_data`);
      const data = await response.json();
      
      this.framesData = data.frames;
      this.totalFrames = data.totalFrames;
      
      console.log(`Loaded ${Object.keys(this.framesData).length} frames with ${data.totalDetections} total detections`);
      
    } catch (error) {
      console.error('フレームデータの読み込みエラー:', error);
    }
  }
  
  setupEventListeners() {
    // 再生中は描画ループを回す
    this.video.addEventListener('play', () => {
      this.isPlaying = true;
      this.renderLoop();
    });
    
    // 一時停止で描画ループを止める
    this.video.addEventListener('pause', () => {
      this.isPlaying = false;
    });
    
    // シークした時も即座に再描画
    this.video.addEventListener('seeked', () => {
      this.updateCanvas();
      this.updateUI();
    });
    
    // BBox表示切り替えボタン
    const toggleBboxBtn = document.getElementById('toggleBbox');
    if (toggleBboxBtn) {
      toggleBboxBtn.addEventListener('click', () => {
        this.showBbox = !this.showBbox;
        toggleBboxBtn.textContent = this.showBbox 
          ? 'Bounding Box 非表示' 
          : 'Bounding Box 表示';
        this.updateCanvas();
      });
    }
    
    // ラベル表示切り替えボタン
    const toggleLabelsBtn = document.getElementById('toggleLabels');
    if (toggleLabelsBtn) {
      toggleLabelsBtn.addEventListener('click', () => {
        this.showLabels = !this.showLabels;
        toggleLabelsBtn.textContent = this.showLabels 
          ? 'ラベル 非表示' 
          : 'ラベル 表示';
        this.updateCanvas();
      });
    }
  }
  
  // 🔁 再生中に滑らかに描画更新するループ
  renderLoop() {
    if (!this.isPlaying) return;

    this.currentFrame = Math.floor(this.video.currentTime * this.fps);
    this.updateCanvas();
    this.updateUI();

    // 次のフレームをリクエスト
    requestAnimationFrame(() => this.renderLoop());
  }
  
  updateUI() {
    const frameInfo = document.getElementById('frameInfo');
    if (frameInfo) {
      frameInfo.textContent = `Frame: ${this.currentFrame}`;
    }
    
    const detectionCount = document.getElementById('detectionCount');
    if (detectionCount) {
      const detections = this.framesData[this.currentFrame] || [];
      detectionCount.textContent = `検出: ${detections.length}人`;
    }
  }
  
  updateCanvas() {
    this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    if (!this.showBbox) return;
    
    const detections = this.framesData[this.currentFrame] || [];
    detections.forEach((detection, index) => {
      this.drawBoundingBox(detection, index);
    });
  }
  
  drawBoundingBox(detection, index) {
    const { x1, y1, x2, y2, activityValue } = detection;
    
    const scaledX1 = x1 * this.scaleX;
    const scaledY1 = y1 * this.scaleY;
    const scaledX2 = x2 * this.scaleX;
    const scaledY2 = y2 * this.scaleY;
    
    const width = scaledX2 - scaledX1;
    const height = scaledY2 - scaledY1;
    
    const color = this.colors[index % this.colors.length];
    
    this.ctx.strokeStyle = color;
    this.ctx.lineWidth = 3;
    this.ctx.strokeRect(scaledX1, scaledY1, width, height);
    
    if (this.showLabels && activityValue !== undefined) {
      const label = `Activity: ${activityValue.toFixed(2)}`;
      this.ctx.fillStyle = color;
      const labelWidth = 150;
      const labelHeight = 25;
      this.ctx.fillRect(scaledX1, scaledY1 - labelHeight, labelWidth, labelHeight);
      
      this.ctx.fillStyle = '#ffffff';
      this.ctx.font = 'bold 14px Arial';
      this.ctx.fillText(label, scaledX1 + 5, scaledY1 - 7);
    }
  }
}

document.addEventListener('turbo:load', () => {
  if (document.getElementById('videoPlayer')) {
    new VideoPlayerWithBBox();
  }
});

// ページロード時に自動初期化
document.addEventListener('DOMContentLoaded', () => {
  if (document.getElementById('videoPlayer')) {
    new VideoPlayerWithBBox();
  }
});
