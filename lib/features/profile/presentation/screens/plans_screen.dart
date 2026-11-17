import 'package:flutter/material.dart';
import 'package:priceshield/core/services/auth_session.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';
import 'package:priceshield/core/theme/app_theme.dart';
import 'package:priceshield/core/widgets/app_ui.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key, this.apiClient});

  final PriceShieldApiClient? apiClient;

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  PriceShieldApiClient get _api => widget.apiClient ?? priceShieldApi;
  bool _loading = true;
  String? _currentPlanId = 'free_shield';
  int _boostCredits = 0;
  String? _subscribingPlanId;

  @override
  void initState() {
    super.initState();
    _loadUserPlan();
  }

  Future<void> _loadUserPlan() async {
    if (!AuthSession.isSignedIn) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final res = await _api.getMyPlan();
      if (!mounted) return;
      final current = res['currentPlan'];
      setState(() {
        _currentPlanId = current?['id']?.toString() ?? 'free_shield';
        _boostCredits = int.tryParse(res['availableBoostCredits']?.toString() ?? '0') ?? 0;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _subscribe(String planId, String planName) async {
    if (!AuthSession.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to select a protection plan.'),
          backgroundColor: PriceShieldColors.navy,
        ),
      );
      Navigator.pushNamed(context, '/signin');
      return;
    }

    setState(() => _subscribingPlanId = planId);
    try {
      await _api.subscribePlan(planId);
      if (!mounted) return;
      setState(() {
        _currentPlanId = planId;
        _boostCredits = planId == 'guardian_pro' ? 999 : (planId == 'priceshield_pro' ? 3 : 0);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Subscribed to $planName successfully!'),
          backgroundColor: PriceShieldColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not complete subscription: $e'),
          backgroundColor: PriceShieldColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _subscribingPlanId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PriceShieldColors.background,
      appBar: AppBar(
        title: const Text('Protection Plans & Boosts'),
        backgroundColor: Colors.white,
        foregroundColor: PriceShieldColors.navy,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Hero Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xff10233F), Color(0xff1A365D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xff10233F).withValues(alpha: 0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xff0F9D8A).withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.shield_rounded, color: Color(0xff57C7A7), size: 28),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PriceShield Priority',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Corporate & Legal Protection SLA',
                                    style: TextStyle(color: Color(0xff94A3B8), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _currentPlanId == 'priceshield_pro'
                              ? '⭐ PriceShield Pro Active — 3 Monthly 24h Complaint Boosts included.'
                              : _currentPlanId == 'guardian_pro'
                                  ? '👑 Shield Guardian VIP Active — Unlimited 4h Fast-Track Boosts.'
                                  : '🛡️ PriceShield Free Shield Active — Standard 5-day grievance moderation.',
                          style: const TextStyle(color: Color(0xffE2E8F0), fontSize: 13, height: 1.4),
                        ),
                        if (_boostCredits > 0) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xff0F9D8A).withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xff0F9D8A).withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bolt_rounded, color: Color(0xffFBBF24), size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  '$_boostCredits Priority Boost Credits Available',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),
                  const Text(
                    'Available Protection Tiers',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: PriceShieldColors.navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Select a plan to accelerate legal Metrology escalation and unlock verified dockets.',
                    style: TextStyle(fontSize: 13, color: PriceShieldColors.muted),
                  ),

                  const SizedBox(height: 18),

                  // Tier 1: PriceShield Pro (POPULAR)
                  _buildPlanCard(
                    id: 'priceshield_pro',
                    name: 'PriceShield Pro',
                    badge: '⚡ MOST POPULAR',
                    badgeColor: const Color(0xff0F9D8A),
                    price: '₹49',
                    interval: 'per month',
                    description: '24-hour priority legal escalation, automated WhatsApp store notice, and verified legal docket.',
                    features: const [
                      '⚡ 24h Priority Complaint Escalation (Fast-Track SLA)',
                      '3 Monthly Priority Complaint Boosts',
                      'Advocate-formatted Legal Metrology Notice',
                      'Automated merchant WhatsApp conciliation notice',
                      'Unlimited cloud receipt & proof backups',
                    ],
                    isCurrent: _currentPlanId == 'priceshield_pro',
                    highlightColor: const Color(0xff0F9D8A),
                  ),

                  const SizedBox(height: 16),

                  // Tier 2: Shield Guardian VIP
                  _buildPlanCard(
                    id: 'guardian_pro',
                    name: 'Shield Guardian VIP',
                    badge: '👑 VIP ESCALATION',
                    badgeColor: const Color(0xff8B5CF6),
                    price: '₹149',
                    interval: 'per month',
                    description: 'Full legal metrology department escalation, direct advocate filing assistance, and legal defense.',
                    features: const [
                      '⚡ 4h Expedited Adjudication SLA',
                      'Unlimited Priority Complaint Boosts',
                      'Direct e-Daakhil / NCH consumer court packet filing',
                      'Anti-retaliation legal defense protection coverage',
                      'Personal consumer grievance advocate liaison',
                    ],
                    isCurrent: _currentPlanId == 'guardian_pro',
                    highlightColor: const Color(0xff8B5CF6),
                  ),

                  const SizedBox(height: 16),

                  // Tier 3: Free Shield
                  _buildPlanCard(
                    id: 'free_shield',
                    name: 'PriceShield Basic',
                    badge: 'STANDARD',
                    badgeColor: const Color(0xff64748B),
                    price: '₹0',
                    interval: 'free forever',
                    description: 'Essential price overcharge checking and community protection.',
                    features: const [
                      'Real-time printed MRP scanner',
                      'Standard 5-7 day grievance moderation',
                      'Consumer forum complaint guidance docket',
                      'Up to 20 product lookups per month',
                    ],
                    isCurrent: _currentPlanId == 'free_shield',
                    highlightColor: const Color(0xff64748B),
                  ),

                  const SizedBox(height: 32),

                  // Boost Explanation Box
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bolt_rounded, color: Color(0xffF59E0B), size: 22),
                            SizedBox(width: 8),
                            Text(
                              'How Complaint Boost Works',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'When you apply a Priority Boost to any filed complaint, our legal moderation desk flags your case in the live dashboard, triggers a 24-hour statutory legal notice to the merchant, and prioritizes evidence verification.',
                          style: TextStyle(fontSize: 13, color: PriceShieldColors.muted, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPlanCard({
    required String id,
    required String name,
    required String badge,
    required Color badgeColor,
    required String price,
    required String interval,
    required String description,
    required List<String> features,
    required bool isCurrent,
    required Color highlightColor,
  }) {
    final isSubscribing = _subscribingPlanId == id;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent ? highlightColor : const Color(0xffE2E8F0),
          width: isCurrent ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: PriceShieldColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'CURRENT PLAN',
                    style: TextStyle(
                      color: PriceShieldColors.success,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: PriceShieldColors.navy,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                price,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: PriceShieldColors.navy,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                interval,
                style: const TextStyle(fontSize: 12, color: PriceShieldColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 12, color: PriceShieldColors.muted, height: 1.35),
          ),
          const Divider(height: 24),
          ...features.map(
            (feat) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded, color: PriceShieldColors.success, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feat,
                      style: const TextStyle(fontSize: 12, color: Color(0xff334155), height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: isCurrent || isSubscribing ? null : () => _subscribe(id, name),
              style: ElevatedButton.styleFrom(
                backgroundColor: highlightColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isSubscribing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      isCurrent ? 'Active Plan' : 'Select $name',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
