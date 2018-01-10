#  台文語料庫

## 走
```bash
sudo apt-get install -y moreutils
```
```bash
time bash -x 走訓練.sh  2>&1 | ts '[%Y-%m-%d %H:%M:%S]' | tee log_run
```
```bash
bash 看結果.sh  | less
```

## 模型資料夾
攏佇`exp/`內底，介紹模型佮因的衍生資料
* `mono`：`unigram孤音`模型
  * `mono_ali`：予`tri1`用
* `tri1`：`bigram雙音`模型
  * `tri1_ali`：予`tri2`用
* `tri2`：`trigram三連音`模型
  * `tri2_ali_nodup`：予`tri3`用
* `tri3`：`LDA+MLLT`模型
  * `tri3_ali_nodup`：予`tri4`用
* `tri4`：`LDA+MLLT+SAT`模型
  * `tri4_denlats_nodup`：予`mmi`佮`mpe`用
  * `tri4_ali_nodup`
    * `tri4_dubm`：予`fmmi`用
    * `tri4_ubm`：予`sgmm2`用
* `tri4_mmi_b0.1`：`MMI`模型
* `tri4_fmmi_b0.1`：`fMMI+MMI`模型
* `tri4_sgmm2`：`SGMM2`模型
  * `tri4_sgmm2_ali`
    * `tri4_sgmm2_denlats`：予`tri4_sgmm2_mmi_b0.1`用
* `tri4_sgmm2_mmi_b0.1`：`MMI+SGMM2`模型
* `tri4_mpe`：`MPE`模型

## 語料分類
攏佇`data/`內底
* `train`：原本語料。分做
  * `train_dev`：試驗語料，4000句
  * `train_nodev`：訓練語料，抾掉試驗語料賰的語料
    * `train_100kshort`
      * `train_30kshort`：用來快速訓練`mono`模型
    * `train_100k`
      * `train_100k_nodup`：用來快速訓練`tri1`、`tri2`模型
    * `train_nodup`：用來訓練較複雜的模型
