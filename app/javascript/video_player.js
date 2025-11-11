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
    this.fps = 30;
    this.showBbox = true;
    this.showLabels = true;
    this.isPlaying = false;
    
    this.colors = ['#00ff00', '#ff0000', '#0000ff', '#ffff00', '#ff00ff', '#00ffff'];
    this.personColors = {}; // 追加: Person IDごとの色マッピング
    
    this.init();
  }
  
  async init() {
    this.video.addEventListener('loadedmetadata', () => {
      this.resizeCanvas();
    });
    
    window.addEventListener('resize', () => {
      this.resizeCanvas();
    });
    
    await this.loadAllFramesData();
    
    this.setupEventListeners();
    
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
      this.performerColors = data.performerColors || {}; // 追加: サーバーから色情報取得
      
      console.log(`Loaded ${Object.keys(this.framesData).length} frames with ${data.totalDetections} total detections`);
      console.log('Performer colors:', this.performerColors);
      
    } catch (error) {
      console.error('フレームデータの読み込みエラー:', error);
    }
  }
  
  // 追加: Person IDに基づいて色を取得
  getColorForPerson(personId) {
    if (!this.personColors[personId]) {
      // まだ色が割り当てられていない場合、新しい色を割り当て
      const colorIndex = Object.keys(this.personColors).length % this.colors.length;
      this.personColors[personId] = this.colors[colorIndex];
      console.log(`Assigned color ${this.colors[colorIndex]} to person ID ${personId}`);
    }
    return this.personColors[personId];
  }
  
  // 追加: Performer名に基づいて色を取得
  getColorForPerformer(performerName) {
    if (this.performerColors && this.performerColors[performerName]) {
      return this.performerColors[performerName];
    }
    return null;
  }
  
  setupEventListeners() {
    this.video.addEventListener('play', () => {
      this.isPlaying = true;
      this.renderLoop();
    });
    
    this.video.addEventListener('pause', () => {
      this.isPlaying = false;
    });
    
    this.video.addEventListener('seeked', () => {
      this.updateCanvas();
      this.updateUI();
    });
    
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
  
  renderLoop() {
    if (!this.isPlaying) return;

    this.currentFrame = Math.floor(this.video.currentTime * this.fps);
    this.updateCanvas();
    this.updateUI();

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
    detections.forEach((detection) => {
      this.drawBoundingBox(detection); // indexは不要になった
    });
  }
  
  drawBoundingBox(detection) {
    const { x1, y1, x2, y2, activityValue, personId, performerName } = detection;
    
    const scaledX1 = x1 * this.scaleX;
    const scaledY1 = y1 * this.scaleY;
    const scaledX2 = x2 * this.scaleX;
    const scaledY2 = y2 * this.scaleY;
    
    const width = scaledX2 - scaledX1;
    const height = scaledY2 - scaledY1;
    
    // 色の優先順位:
    // 1. Performer名ベースの色（演者紐付け済み）
    // 2. Person IDベースの色
    // 3. デフォルトの緑色
    let color;
    if (performerName) {
      color = this.getColorForPerformer(performerName) || this.getColorForPerson(personId);
    } else if (personId !== undefined && personId !== null) {
      color = this.getColorForPerson(personId);
    } else {
      color = '#00ff00'; // デフォルト
    }
    
    this.ctx.strokeStyle = color;
    this.ctx.lineWidth = 3;
    this.ctx.strokeRect(scaledX1, scaledY1, width, height);
    
    if (this.showLabels) {
      // ラベルテキストの決定
      let label;
      if (performerName) {
        label = `${performerName}: ${activityValue?.toFixed(2) || 'N/A'}`;
      } else if (personId !== undefined && personId !== null) {
        label = `Person ${personId}: ${activityValue?.toFixed(2) || 'N/A'}`;
      } else {
        label = `Activity: ${activityValue?.toFixed(2) || 'N/A'}`;
      }
      
      this.ctx.fillStyle = color;
      const labelWidth = 180;
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
