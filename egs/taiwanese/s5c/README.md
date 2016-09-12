#  台文語料庫

## 走
```bash
time bash -x run.sh  2>&1 | ts '[%Y-%m-%d %H:%M:%S]' | tee log_run_sp
```
```bash
bash 看結果.sh  | less
```

## 語料分類
* `train`，原本語料。分做
  * `train_dev`，試驗語料，4000句
  * `train_nodev`，訓練語料，抾掉試驗語料賰的語料
    * `train_100kshort`
      * `train_30kshort`，用來快速訓練`mono`模型
    * `train_100k`
      * `train_100k_nodup`，用來快速訓練`tri1`、`tri2`模型
    * `train_nodup`，用來訓練較複雜的模型
