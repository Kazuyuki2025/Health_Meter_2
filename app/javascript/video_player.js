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
    
    this.colors = ['#00ff00', '#ff0000', '#0000ff', '#ff00ff', '#ffff00', '#00ffff'];
    this.personColors = {};
    
    this.init();
  }
  
  async init() {
    this.video.addEventListener('loadedmetadata', () => {
      this.resizeCanvas();
      this.setupFrameControls(); // フレーム制御UIを初期化
    });
    
    window.addEventListener('resize', () => {
      this.resizeCanvas();
    });
    
    await this.loadAllFramesData();
    
    this.setupEventListeners();
    
    this.updateCanvas();
  }

  // 新しいメソッド: フレーム制御UIのセットアップ
  setupFrameControls() {
    // フレームジャンプ用のUIを追加
    this.addFrameJumpControls();
    
    // フレームスライダーを追加
    this.addFrameSlider();
  }

  addFrameJumpControls() {
    // 既存のコントロール要素を取得または作成
    let controlsContainer = document.getElementById('frameControls');
    if (!controlsContainer) {
      controlsContainer = document.createElement('div');
      controlsContainer.id = 'frameControls';
      controlsContainer.className = 'frame-controls mt-3 mb-3';
      
      // 動画プレイヤーの後に挿入
      const videoContainer = this.video.parentNode;
      videoContainer.insertAdjacentElement('afterend', controlsContainer);
    }

    controlsContainer.innerHTML = `
      <div class="row">
        <div class="col-md-6">
          <div class="card">
            <div class="card-body">
              <h6 class="card-title">フレームジャンプ</h6>
              <div class="input-group">
                <input type="number" id="frameInput" class="form-control" 
                       placeholder="フレーム番号" min="0" max="${this.totalFrames - 1}">
                <button class="btn btn-primary" id="jumpToFrameBtn">移動</button>
              </div>
              <small class="text-muted">0 ～ ${this.totalFrames - 1} フレーム</small>
            </div>
          </div>
        </div>
        
        <div class="col-md-6">
          <div class="card">
            <div class="card-body">
              <h6 class="card-title">フレーム操作</h6>
              <div class="btn-group" role="group">
                <button class="btn btn-outline-secondary" id="prevFrameBtn">◀ 前</button>
                <button class="btn btn-outline-secondary" id="nextFrameBtn">次 ▶</button>
                <button class="btn btn-outline-info" id="frameZeroBtn">最初</button>
                <button class="btn btn-outline-warning" id="frameEndBtn">最後</button>
              </div>
            </div>
          </div>
        </div>
      </div>
      
      <div class="row mt-2">
        <div class="col-12">
          <div class="card">
            <div class="card-body">
              <h6 class="card-title">フレームスライダー</h6>
              <input type="range" id="frameSlider" class="form-range" 
                     min="0" max="${this.totalFrames - 1}" value="0" step="1">
              <div class="d-flex justify-content-between">
                <small>0</small>
                <small id="currentFrameDisplay">フレーム: 0</small>
                <small>${this.totalFrames - 1}</small>
              </div>
            </div>
          </div>
        </div>
      </div>
    `;

    // イベントリスナーを設定
    this.setupFrameControlListeners();
  }

  addFrameSlider() {
    // フレームスライダーは addFrameJumpControls() で既に追加済み
  }

  setupFrameControlListeners() {
    // フレームジャンプボタン
    const jumpBtn = document.getElementById('jumpToFrameBtn');
    const frameInput = document.getElementById('frameInput');
    
    if (jumpBtn && frameInput) {
      jumpBtn.addEventListener('click', () => {
        this.jumpToFrame(parseInt(frameInput.value));
      });
      
      frameInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
          this.jumpToFrame(parseInt(frameInput.value));
        }
      });
    }

    // 前/次フレームボタン
    const prevBtn = document.getElementById('prevFrameBtn');
    const nextBtn = document.getElementById('nextFrameBtn');
    
    if (prevBtn) {
      prevBtn.addEventListener('click', () => {
        this.jumpToFrame(this.currentFrame - 1);
      });
    }
    
    if (nextBtn) {
      nextBtn.addEventListener('click', () => {
        this.jumpToFrame(this.currentFrame + 1);
      });
    }

    // 最初/最後フレームボタン
    const frameZeroBtn = document.getElementById('frameZeroBtn');
    const frameEndBtn = document.getElementById('frameEndBtn');
    
    if (frameZeroBtn) {
      frameZeroBtn.addEventListener('click', () => {
        this.jumpToFrame(0);
      });
    }
    
    if (frameEndBtn) {
      frameEndBtn.addEventListener('click', () => {
        this.jumpToFrame(this.totalFrames - 1);
      });
    }

    // フレームスライダー
    const frameSlider = document.getElementById('frameSlider');
    if (frameSlider) {
      frameSlider.addEventListener('input', (e) => {
        this.jumpToFrame(parseInt(e.target.value));
      });
    }
  }

  // 新しいメソッド: 指定フレームにジャンプ
  jumpToFrame(frameNumber) {
    // フレーム番号の妥当性チェック
    if (isNaN(frameNumber)) {
      alert('有効なフレーム番号を入力してください');
      return;
    }
    
    if (frameNumber < 0) {
      frameNumber = 0;
    }
    
    if (frameNumber >= this.totalFrames) {
      frameNumber = this.totalFrames - 1;
    }
    
    // 動画の時間を計算してシーク
    const targetTime = frameNumber / this.fps;
    this.video.currentTime = targetTime;
    
    // 現在フレームを更新
    this.currentFrame = frameNumber;
    
    // UIを更新
    this.updateFrameUI();
    
    console.log(`Jumped to frame ${frameNumber} (time: ${targetTime.toFixed(3)}s)`);
  }

  // 新しいメソッド: フレーム関連UIの更新
  updateFrameUI() {
    // フレーム番号の表示を更新
    const frameInput = document.getElementById('frameInput');
    if (frameInput) {
      frameInput.value = this.currentFrame;
    }
    
    // スライダーの位置を更新
    const frameSlider = document.getElementById('frameSlider');
    if (frameSlider) {
      frameSlider.value = this.currentFrame;
    }
    
    // 現在フレーム表示を更新
    const currentFrameDisplay = document.getElementById('currentFrameDisplay');
    if (currentFrameDisplay) {
      currentFrameDisplay.textContent = `フレーム: ${this.currentFrame}`;
    }
    
    // 既存のUIも更新
    this.updateUI();
    this.updateCanvas();
  }

  // 修正されたメソッド: 既存のUIアップデート
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

    // 時間情報も表示
    const timeInfo = document.getElementById('timeInfo');
    if (timeInfo) {
      const currentTime = this.currentFrame / this.fps;
      timeInfo.textContent = `時間: ${currentTime.toFixed(2)}秒`;
    }
  }

  // 修正されたメソッド: レンダリングループ
  renderLoop() {
    if (!this.isPlaying) return;

    this.currentFrame = Math.floor(this.video.currentTime * this.fps);
    this.updateFrameUI(); // フレーム関連UI全体を更新

    requestAnimationFrame(() => this.renderLoop());
  }

  // 修正されたメソッド: イベントリスナー設定
  setupEventListeners() {
    this.video.addEventListener('play', () => {
      this.isPlaying = true;
      this.renderLoop();
    });
    
    this.video.addEventListener('pause', () => {
      this.isPlaying = false;
    });
    
    this.video.addEventListener('seeked', () => {
      this.currentFrame = Math.floor(this.video.currentTime * this.fps);
      this.updateFrameUI();
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

    // キーボードショートカットを追加
    document.addEventListener('keydown', (e) => {
      // 入力フィールドにフォーカスがある場合は無視
      if (document.activeElement.tagName === 'INPUT') return;
      
      switch(e.key) {
        case 'ArrowLeft':
          e.preventDefault();
          this.jumpToFrame(this.currentFrame - 1);
          break;
        case 'ArrowRight':
          e.preventDefault();
          this.jumpToFrame(this.currentFrame + 1);
          break;
        case 'Home':
          e.preventDefault();
          this.jumpToFrame(0);
          break;
        case 'End':
          e.preventDefault();
          this.jumpToFrame(this.totalFrames - 1);
          break;
      }
    });
  }

  // 既存のメソッドはそのまま保持
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
      this.performerColors = data.performerColors || {};
      
      console.log(`Loaded ${Object.keys(this.framesData).length} frames with ${data.totalDetections} total detections`);
      console.log('Performer colors:', this.performerColors);
      
      // フレーム数が判明したらコントロールを更新
      if (this.totalFrames) {
        this.updateFrameControlsMaxValues();
      }
      
    } catch (error) {
      console.error('フレームデータの読み込みエラー:', error);
    }
  }

  // 新しいメソッド: フレームコントロールの最大値を更新
  updateFrameControlsMaxValues() {
    const frameInput = document.getElementById('frameInput');
    const frameSlider = document.getElementById('frameSlider');
    
    if (frameInput) {
      frameInput.max = this.totalFrames - 1;
    }
    
    if (frameSlider) {
      frameSlider.max = this.totalFrames - 1;
    }
  }
  
  getColorForPerson(personId) {
    if (!this.personColors[personId]) {
      const colorIndex = Object.keys(this.personColors).length % this.colors.length;
      this.personColors[personId] = this.colors[colorIndex];
      console.log(`Assigned color ${this.colors[colorIndex]} to person ID ${personId}`);
    }
    return this.personColors[personId];
  }
  
  getColorForPerformer(performerName) {
    if (this.performerColors && this.performerColors[performerName]) {
      return this.performerColors[performerName];
    }
    return null;
  }
  
  updateCanvas() {
    this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    if (!this.showBbox) return;
    
    const detections = this.framesData[this.currentFrame] || [];
    detections.forEach((detection) => {
      this.drawBoundingBox(detection);
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
    
    let color;
    if (performerName) {
      color = this.getColorForPerformer(performerName) || this.getColorForPerson(personId);
    } else if (personId !== undefined && personId !== null) {
      color = this.getColorForPerson(personId);
    } else {
      color = '#00ff00';
    }
    
    this.ctx.strokeStyle = color;
    this.ctx.lineWidth = 3;
    this.ctx.strokeRect(scaledX1, scaledY1, width, height);
    
    if (this.showLabels) {
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

document.addEventListener('DOMContentLoaded', () => {
  if (document.getElementById('videoPlayer')) {
    new VideoPlayerWithBBox();
  }
});
