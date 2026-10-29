#!/usr/bin/env python3
"""应用打印机 App 所需的平台权限与应用名补丁（在 `flutter create` 生成原生工程之后运行）。

- iOS: 添加本地网络 / mDNS 发现所需的 NSLocalNetworkUsageDescription 与
       NSBonjourServices（含 _ipp._tcp / _printer._tcp / _epson._tcp，爱普生 L3250 需要）；
       设置 CFBundleDisplayName / CFBundleName 为应用名
- Android: 确保 CHANGE_WIFI_MULTICAST_STATE 权限、为主 Activity 添加
           SEND / SEND_MULTIPLE 系统分享 intent-filter、queries 块（微信分享），
           以及 application android:label 应用名

幂等：已存在则跳过，可重复运行。
"""
import os

import plistlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP_NAME = "王婉宁打印"


def patch_ios():
    path = os.path.join(ROOT, "ios", "Runner", "Info.plist")
    if not os.path.exists(path):
        print("[iOS] 未找到 Info.plist，跳过（请先运行 flutter create）")
        return
    with open(path, "rb") as f:
        data = plistlib.load(f)
    changed = False

    if "NSLocalNetworkUsageDescription" not in data:
        data["NSLocalNetworkUsageDescription"] = "需要访问本地网络以发现同一 WiFi 下的打印机"
        changed = True

    svc = list(data.get("NSBonjourServices", []))
    for s in ("_ipp._tcp", "_printer._tcp", "_epson._tcp"):
        if s not in svc:
            svc.append(s)
            changed = True
    if "NSBonjourServices" not in data or svc != data.get("NSBonjourServices"):
        data["NSBonjourServices"] = svc
        changed = True

    for k, v in (
        ("NSCameraUsageDescription", "用于拍照并打印照片/身份证"),
        ("NSPhotoLibraryUsageDescription", "用于从相册选择要打印的图片"),
        ("NSPhotoLibraryAddUsageDescription", "用于保存打印预览图"),
        # 应用名（flutter create 默认为工程名，统一改为产品名）
        ("CFBundleDisplayName", APP_NAME),
        ("CFBundleName", APP_NAME),
    ):
        if data.get(k) != v:
            data[k] = v
            changed = True

    if changed:
        with open(path, "wb") as f:
            plistlib.dump(data, f)
        print("[iOS] Info.plist 已更新（NSBonjourServices=%s）" % svc)
    else:
        print("[iOS] Info.plist 已包含所需权限，无需修改")


def patch_android():
    import xml.etree.ElementTree as ET

    path = os.path.join(ROOT, "android", "app", "src", "main", "AndroidManifest.xml")
    if not os.path.exists(path):
        print("[Android] 未找到 AndroidManifest.xml，跳过（请先运行 flutter create）")
        return
    ET.register_namespace("android", "http://schemas.android.com/apk/res/android")
    tree = ET.parse(path)
    root = tree.getroot()
    A = "{http://schemas.android.com/apk/res/android}"
    changed = False

    def has_perm(name):
        return any(p.get(A + "name") == name for p in root.findall("uses-permission"))

    def add_perm(name):
        el = ET.SubElement(root, "uses-permission")
        el.set(A + "name", name)

    if not has_perm("android.permission.INTERNET"):
        add_perm("android.permission.INTERNET")
        changed = True
    if not has_perm("android.permission.CHANGE_WIFI_MULTICAST_STATE"):
        add_perm("android.permission.CHANGE_WIFI_MULTICAST_STATE")
        changed = True

    # 应用名（android:label，flutter create 默认为工程名）
    application = root.find("application")
    if application is not None and application.get(A + "label") != APP_NAME:
        application.set(A + "label", APP_NAME)
        changed = True

    activity = next(
        (act for act in root.iter("activity")
         if (act.get(A + "name") or "").endswith("MainActivity")),
        None,
    )
    if activity is None:
        print("[Android] 未找到 MainActivity，跳过 intent-filter 补丁")
    else:
        def has_action(action):
            for f in activity.findall("intent-filter"):
                if any(a.get(A + "name") == action for a in f.findall("action")):
                    return True
            return False

        def add_send_filter(action):
            f = ET.SubElement(activity, "intent-filter")
            a = ET.SubElement(f, "action")
            a.set(A + "name", action)
            c = ET.SubElement(f, "category")
            c.set(A + "name", "android.intent.category.DEFAULT")
            d = ET.SubElement(f, "data")
            d.set(A + "mimeType", "image/*")

        if not has_action("android.intent.action.SEND"):
            add_send_filter("android.intent.action.SEND")
            changed = True
        if not has_action("android.intent.action.SEND_MULTIPLE"):
            add_send_filter("android.intent.action.SEND_MULTIPLE")
            changed = True

    if root.find("queries") is None:
        q = ET.SubElement(root, "queries")
        for action in ("android.intent.action.SEND", "android.intent.action.SEND_MULTIPLE"):
            intent = ET.SubElement(q, "intent")
            a = ET.SubElement(intent, "action")
            a.set(A + "name", action)
            d = ET.SubElement(intent, "data")
            d.set(A + "mimeType", "image/*")
        changed = True

    if changed:
        tree.write(path, encoding="utf-8", xml_declaration=True)
        print("[Android] AndroidManifest.xml 已更新（分享/多播权限已补）")
    else:
        print("[Android] AndroidManifest.xml 已包含所需配置，无需修改")


if __name__ == "__main__":
    patch_ios()
    patch_android()
    print("权限补丁完成。")
