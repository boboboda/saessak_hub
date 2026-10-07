/// 보상형 광고 자리. 지금은 광고 없이 바로 보상을 주는 임시 구현이다.
/// 실제 광고(google_mobile_ads)를 붙일 때 이 함수 안만 바꾸면 된다.
class AdService {
  static Future<bool> showRewarded() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return true; // 광고를 끝까지 봤으면 true
  }
}
