import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

///苹果应用内支付(IPA)

///App 内购买项目共有四种类型：消耗型、非消耗型、自动续期订阅和非续期订阅
const String _kConsumableId = 'consumable';
const String _kUpgradeId = 'upgrade';
const String _kSilverSubscriptionId = 'subscription_silver';
const String _kGoldSubscriptionId = 'subscription_gold';
const List<String> _kProductIds = <String>[
  _kConsumableId,
  _kUpgradeId,
  _kSilverSubscriptionId,
  _kGoldSubscriptionId,
];

class ApplePayKit {
  static late final ApplePayKit _instance = ApplePayKit._internal();
  factory ApplePayKit() => _instance;
  late InAppPurchase _inAppPurchase; //应用内支付实例
  StreamSubscription<List<PurchaseDetails>>? _applePayListener;
  ApplePayKit._internal() {
    _inAppPurchase = InAppPurchase.instance;
  }

  ///是否可以使用支付
  Future<bool> isAvailable() => _inAppPurchase.isAvailable();

  ///设置支付回调
  void setApplePayResponseEventHandler() {
    final Stream<List<PurchaseDetails>> purchaseUpdated =
        _inAppPurchase.purchaseStream;
    _applePayListener = purchaseUpdated.listen(
      (purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () {
        _applePayListener?.cancel();
      },
      onError: (error) {
        debugPrint('setApplePayResponseEventHandler ${error.toString()}');
      },
    );
  }

  Future<void> _listenToPurchaseUpdated(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (PurchaseDetails purchaseDetails in purchaseDetailsList) {
      PurchaseStatus status = purchaseDetails.status;
      if (status == PurchaseStatus.pending) {
        // show pending ui
      } else {
        if (status == PurchaseStatus.error) {
          // handle error here
        } else if (status == PurchaseStatus.purchased ||
            status == PurchaseStatus.restored) {
          bool valid = await _verifyPurchase(purchaseDetails);
          if (valid) {
            deliverProduct(purchaseDetails);
          } else {
            _handleInvalidPurchase(purchaseDetails);
            return;
          }
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) {
    // IMPORTANT! Always verify a purchase before delivering the product;
    return Future<bool>.value(true);
  }

  void deliverProduct(PurchaseDetails purchaseDetails) {
    // IMPORTANT! Always verify a purchase before delivering the product;
  }

  void _handleInvalidPurchase(PurchaseDetails purchaseDetails) {
    // handle invalid purchase here if _verifyPurchase failed
  }
  void handleError(IAPError error) {}

  ///获取商品列表
  Future<List<ProductDetails>> getProductList() async {
    var iOSPlatformAddition = _inAppPurchase
        .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
    await iOSPlatformAddition.setDelegate(ApplePaymentQueueDelegate());
    ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails(_kProductIds.toSet());
    if (response.error != null) {
      debugPrint('ApplePayKit getProductList error code=${response.error!.code}'
          ' message=${response.error!.message} details=${response.error!.details}');
      return <ProductDetails>[];
    }
    return response.productDetails;
  }

  ///发起支付
  void payByApple(ProductDetails productDetails) {
    final PurchaseParam purchaseParam =
        PurchaseParam(productDetails: productDetails);
    if (productDetails.id == _kConsumableId) {
      _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
    } else {
      _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    }
  }
}

class ApplePaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(
      SKPaymentTransactionWrapper transaction, SKStorefrontWrapper storefront) {
    return true;
  }

  @override
  bool shouldShowPriceConsent() {
    return false;
  }
}
