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
    this.fps = 60; // 動画のFPS（必要に応じて調整）
    this.showBbox = true;
    this.showLabels = true;
    
    this.colors = ['#00ff00', '#ff0000', '#0000ff', '#ffff00', '#ff00ff', '#00ffff'];
    
    this.init();
  }
  
  async init() {
    // キャンバスのサイズを動画に合わせる
    this.video.addEventListener('loadedmetadata', () => {
      this.resizeCanvas();
    });
    
    // 動画のリサイズ時にキャンバスも調整
    window.addEventListener('resize', () => {
      this.resizeCanvas();
    });
    
    // 全フレームデータを読み込み
    await this.loadAllFramesData();
    
    // イベントリスナー設定
    this.setupEventListeners();
    
    // 初期描画
    this.updateCanvas();
  }
  
  resizeCanvas() {
    // 動画の表示サイズを取得
    const rect = this.video.getBoundingClientRect();
    this.canvas.width = rect.width;
    this.canvas.height = rect.height;
    
    // 動画の実際のサイズ
    this.videoWidth = this.video.videoWidth;
    this.videoHeight = this.video.videoHeight;
    
    // スケール計算
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
    // 動画の時間更新イベント
    this.video.addEventListener('timeupdate', () => {
      this.currentFrame = Math.floor(this.video.currentTime * this.fps);
      this.updateCanvas();
      this.updateUI();
    });
    
    // Bounding Box表示切り替え
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
    
    // ラベル表示切り替え
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
    
    // 動画の再生/一時停止でも再描画
    this.video.addEventListener('play', () => this.updateCanvas());
    this.video.addEventListener('pause', () => this.updateCanvas());
    this.video.addEventListener('seeked', () => this.updateCanvas());
  }
  
  updateUI() {
    // フレーム情報を更新
    const frameInfo = document.getElementById('frameInfo');
    if (frameInfo) {
      frameInfo.textContent = `Frame: ${this.currentFrame}`;
    }
    
    // 検出数を更新
    const detectionCount = document.getElementById('detectionCount');
    if (detectionCount) {
      const detections = this.framesData[this.currentFrame] || [];
      detectionCount.textContent = `検出: ${detections.length}人`;
    }
  }
  
  updateCanvas() {
    // キャンバスをクリア
    this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    
    if (!this.showBbox) return;
    
    // 現在のフレームの検出データを取得
    const detections = this.framesData[this.currentFrame] || [];
    
    // 各検出結果を描画
    detections.forEach((detection, index) => {
      this.drawBoundingBox(detection, index);
    });
  }
  
  drawBoundingBox(detection, index) {
    const { x1, y1, x2, y2, activityValue } = detection;
    
    // 座標をキャンバスのスケールに変換
    const scaledX1 = x1 * this.scaleX;
    const scaledY1 = y1 * this.scaleY;
    const scaledX2 = x2 * this.scaleX;
    const scaledY2 = y2 * this.scaleY;
    
    const width = scaledX2 - scaledX1;
    const height = scaledY2 - scaledY1;
    
    // 色を選択（検出順に色を割り当て）
    const color = this.colors[index % this.colors.length];
    
    // 矩形を描画
    this.ctx.strokeStyle = color;
    this.ctx.lineWidth = 3;
    this.ctx.strokeRect(scaledX1, scaledY1, width, height);
    
    // ラベルを描画
    if (this.showLabels && activityValue !== undefined) {
      const label = `Activity: ${activityValue.toFixed(2)}`;
      
      // ラベル背景
      this.ctx.fillStyle = color;
      const labelWidth = 150;
      const labelHeight = 25;
      this.ctx.fillRect(scaledX1, scaledY1 - labelHeight, labelWidth, labelHeight);
      
      // ラベルテキスト
      this.ctx.fillStyle = '#ffffff';
      this.ctx.font = 'bold 14px Arial';
      this.ctx.fillText(label, scaledX1 + 5, scaledY1 - 7);
    }
  }
}

// ページ読み込み時に初期化
document.addEventListener('DOMContentLoaded', () => {
  if (document.getElementById('videoPlayer')) {
    new VideoPlayerWithBBox();
  }
});