# inf

PXEサーバー構築シェルとVirtualBoxの仮想マシンのプロビジョニング・ブートシェルを提供する。

## PXEサーバー設定

* RPMパッケージアップデート
* DHCPインストール
    * DHCPコンフィギュレーション
* TFTPインストール
    * ブートローダSYSLINUXインストール
    * SYSLINUXをTFTPに配置
    * ディストリビューションISOイメージダウンロード、マウント
    * ISOイメージのブート用ファイルをTFTPに配置
    * PXEコンフィギュレーション
* Apache httpdインストール
    * Apache httpdコンフィギュレーション
* キックスタートファイルのコンフィギュレーション

## 環境

- PXEサーバー：192.168.255.2/24
- 新規サーバー：192.168.255.200/24（DHCPの始まり200が割り当てられる）

## how to generate sha-512

```python
python3 -c 'import crypt; print(crypt.crypt("password", crypt.METHOD_SHA512))'
```

```sh
echo -n "password" | openssl passwd -6 -stdin
```
