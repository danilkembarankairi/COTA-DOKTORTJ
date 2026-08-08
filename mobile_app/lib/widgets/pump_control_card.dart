import 'package:flutter/material.dart';

class PumpControlCard extends StatefulWidget {
  final bool isOn;
  final VoidCallback onToggle;

  const PumpControlCard({
    Key? key,
    required this.isOn,
    required this.onToggle,
  }) : super(key: key);

  State<PumpControlCard> createState() => _PumpControlCardState();
}

class _PumpControlCardState extends State<PumpControlCard> {
  // ✅ Timer dan countdown sudah DIHAPUS

  // 🎨 Warna utama COTA Emerald (konsisten dengan dashboard)
  static const Color _emerald = Color(0xFF10B981);
  static const Color _emeraldDark = Color(0xFF059669);

  void _handleToggle() {
    // Hanya panggil onToggle, biarkan ESP32 yang mengatur timer
    widget.onToggle();
  }

  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.isOn
              // ✅ Mode ON: Emerald gradient premium
              ? [
                  _emerald,
                  _emeraldDark,
                ]
              // ✅ Mode OFF: abu-abu lembut, adaptif dark/light
              : isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF334155)]
                  : [Colors.grey.shade100, Colors.grey.shade200],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isOn
              ? _emerald.withOpacity(0.4)
              : (isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.grey.shade200),
        ),
        boxShadow: [
          BoxShadow(
            color:
                (widget.isOn ? _emerald : (isDark ? Colors.black : Colors.grey))
                    .withOpacity(widget.isOn ? 0.3 : 0.08),
            blurRadius: widget.isOn ? 20 : 12,
            offset: const Offset(0, 6),
            spreadRadius: widget.isOn ? -2 : 0,
          ),
        ],
      ),
      child: Row(
        children: [
          // 🎨 Icon dengan background gradient
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.isOn
                    ? [
                        Colors.white.withOpacity(0.35),
                        Colors.white.withOpacity(0.15),
                      ]
                    : [
                        _emerald.withOpacity(isDark ? 0.25 : 0.15),
                        _emerald.withOpacity(isDark ? 0.12 : 0.06),
                      ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.isOn
                    ? Colors.white.withOpacity(0.3)
                    : (_emerald.withOpacity(isDark ? 0.3 : 0.2)),
                width: 1.5,
              ),
            ),
            child: Icon(
              widget.isOn
                  ? Icons.water_drop_rounded
                  : Icons.water_drop_outlined,
              color: widget.isOn
                  ? Colors.white
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              size: 32,
            ),
          ),
          const SizedBox(width: 16),

          // 🎨 Teks adaptif
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pompa Air',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                    color: widget.isOn
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.grey.shade800),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: widget.isOn
                            ? Colors.white
                            : (isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade400),
                        shape: BoxShape.circle,
                        boxShadow: widget.isOn
                            ? [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.5),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.isOn ? 'Sedang Menyala' : 'Sedang Mati',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: widget.isOn
                            ? Colors.white.withOpacity(0.95)
                            : (isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
                // ✅ Countdown indicator sudah DIHAPUS
              ],
            ),
          ),

          // 🎨 Switch premium dengan animasi native
          Switch.adaptive(
            value: widget.isOn,
            onChanged: (_) => _handleToggle(),
            activeColor: Colors.white,
            activeTrackColor: Colors.white.withOpacity(0.35),
            inactiveThumbColor:
                isDark ? Colors.grey.shade500 : Colors.grey.shade500,
            inactiveTrackColor:
                isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
        ],
      ),
    );
  }
}
