# Health_Meter_2 (体調診断システム)
## 概要
Health_Meter_2 は，[Health_Meter]() を運用化するために新しく実装したシステムである．
本システムの目的は，ラジオ体操動画を解析し，得られた動画情報，活動量情報や演者情報を管理し，ユーザが
日々の活動量を比較することで演者の体調診断を行えるようにすることである．

## 主要機能
* 動画のアップロード，解析，表示機能
   * 動画をアップロードし，任意のタイミングで解析
   * 解析完了した動画を，BBox がついた状態で再生する
* 演者登録，表示機能
   * 演者の登録，表示
* 元気ランキング
   * 活動量が大きい順に演者を表示
* 体調不良の疑いのある演者
   * 最新の活動量が閾値を下回った場合にその演者を表示
## setup
1. リポジトリをクローン
   '''bash
   https://github.com/Kazuyuki2025/Health_Meter_2.git
   '''

2. 依存関係のインストール
   '''bash
   bundle install
   '''

3. データベースの作成，マイグレーション実行
   '''bash
   rails db:create
   rails db:migrate
   '''

4. サーバの起動
   '''bash
   rails server
   '''
5. ブラウザで[http://localhost:3000](http://localhost:3000) にアクセス

---

## 環境構築
1. **Ruby / Rails のインストール**
   ''' bash
   rbenv install 3.2.3
   gem install rails
   '''
   - `bundle install` を実行し、Gemfile で指定されたライブラリをインストール
  
2. **Python環境の構築**
   [Health_Meter](https://github.com/KentaYoshioka/Health_Meter.git) を参照

---

## 実行環境

- **Ruby / Rails**: Ruby 3.2.3 / Rails 8.0.2
- **Python**: 3.12.3  
- **DBサーバ**: SQLite 
