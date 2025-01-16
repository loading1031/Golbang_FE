import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/club.dart';
import '../../models/enum/event.dart';
import '../../repoisitory/secure_storage.dart';
import '../../services/club_service.dart';
import 'event_create2.dart';
import 'widgets/location_search_dialog.dart';
import 'widgets/participant_dialog.dart';
import '../../models/profile/member_profile.dart';

class EventsCreate1 extends ConsumerStatefulWidget {
  final DateTime? startDay;

  const EventsCreate1({super.key, this.startDay});

  @override
  _EventsCreate1State createState() => _EventsCreate1State();
}

class _EventsCreate1State extends ConsumerState<EventsCreate1> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  late final TextEditingController _startDateController;
  final TextEditingController _startTimeController = TextEditingController(text: "11:00 AM");
  final TextEditingController _endDateController = TextEditingController();
  LatLng? _selectedLocation;
  late String _site;
  List<Club> _clubs = [];
  Club? _selectedClub;
  GameMode? _selectedGameMode;
  List<ClubMemberProfile> _selectedParticipants = [];
  late ClubService _clubService;
  bool _isButtonEnabled = false;
  final Map<String, LatLng> _locationCoordinates = {
    "Jagorawi Golf & Country Club": const LatLng(-6.454673, 106.876867),
    "East Point Golf Club": const LatLng(17.763526, 83.301727),
    "Rusutsu Resort Golf 72": const LatLng(42.748674, 140.904709),
    "Siem Reap Lake Resort Golf Club": const LatLng(13.368188, 103.964219),
    "National Army, Taelung Sport Center": const LatLng(37.630121, 127.109333),
    "Luang Prabang Golf Club": const LatLng(19.867596, 102.085709),
    "Nuwara Eliya Golf Club": const LatLng(6.971707, 80.765661),
    "Bukit Banang Golf & Country Club": const LatLng(1.802658, 102.968811),
    "Panya Indra Golf Club": const LatLng(13.828058, 100.687627),
    "Song Be Golf Resort": const LatLng(10.924936, 106.707254)
  };

  final TimeOfDay _fixedTime = const TimeOfDay(hour: 23, minute: 59);

  @override
  void initState() {
    super.initState();


    // widget.startDay를 날짜 포맷을 사용하여 문자열로 변환
    String? formattedDate = widget.startDay != null
        ? DateFormat('yyyy-MM-dd').format(widget.startDay!)
        : null; // null일 때 기본 값을 처리할 수 있음

    // 변환된 문자열을 초기 값으로 설정
    _startDateController = TextEditingController(text: formattedDate);
    _clubService = ClubService(ref.read(secureStorageProvider));
    _fetchClubs();
    _setupListeners();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 시간을 didChangeDependencies에서 초기화
    final now = TimeOfDay.now();
    _startTimeController.text = now.format(context); // 현재 시간으로 초기화
  }

  DateTime _convertToDateTime(DateTime date, TimeOfDay time) {

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);

  }

  void _setupListeners() {
    _titleController.addListener(_validateForm);
    _locationController.addListener(_validateForm);
    _startDateController.addListener(_validateForm);
    _endDateController.addListener(_validateForm);
  }

  void _validateForm() {
    final isValid = _titleController.text.isNotEmpty &&
        _locationController.text.isNotEmpty &&
        _startDateController.text.isNotEmpty &&
        _endDateController.text.isNotEmpty &&
        _selectedLocation != null &&
        _selectedClub != null &&
        _selectedGameMode != null;

    setState(() {
      _isButtonEnabled = isValid;
    });
  }

  Future<void> _fetchClubs() async {
    try {
      List<Club> clubs = await _clubService.getClubList(isAdmin: true);
      setState(() {
        _clubs = clubs;
      });
    } catch (e) {
      print("Failed to load clubs: $e");
    }
  }

  void _showLocationSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => LocationSearchDialog(
        locationController: _locationController,
        locationCoordinates: _locationCoordinates,
        onLocationSelected: (String site) {
          setState(() {
            _site = site;
            _selectedLocation = _locationCoordinates[site];
            _validateForm();
          });
        },
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      setState(() {
        final formattedDate = "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
        if (isStartDate) {
          _startDateController.text = formattedDate;
        } else {
          _endDateController.text = formattedDate;
        }
        _validateForm();
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime != null) {
      setState(() {
        _startTimeController.text = pickedTime.format(context);
        print('startTime: ${_startTimeController.text}');
      });
    }
  }


  TimeOfDay _parseTimeOfDay(String time) {
    // 공백 제거 및 입력 문자열 정리
    time = time.trim();

    // 한국어 형식 처리: "오전 6:00" 또는 "오후 6:00"
    if (time.startsWith('오전') || time.startsWith('오후')) {
      final isPM = time.startsWith('오후'); // 오후 여부 확인
      final timeParts = time.replaceFirst(RegExp(r'오전|오후'), '').trim(); // "오전" 또는 "오후" 제거

      final timeOfDayParts = timeParts.split(':'); // "6:00" -> ["6", "00"]
      if (timeOfDayParts.length != 2) {
        throw FormatException('Invalid time format: $time'); // 형식 오류
      }

      final hour = int.parse(timeOfDayParts[0]);
      final minute = int.parse(timeOfDayParts[1]);

      return TimeOfDay(
        hour: isPM ? (hour == 12 ? 12 : hour + 12) : (hour == 12 ? 0 : hour),
        minute: minute,
      );
    }

    // 영어 형식 처리: "6:00 AM" 또는 "6:00 PM"
    final timeParts = time.split(' '); // "6:00 AM" -> ["6:00", "AM"]
    if (timeParts.length != 2) {
      throw FormatException('Invalid time format: $time'); // 형식 오류
    }

    final timeOfDayParts = timeParts[0].split(':'); // "6:00" -> ["6", "00"]
    if (timeOfDayParts.length != 2) {
      throw FormatException('Invalid time format: $time'); // 형식 오류
    }

    final hour = int.parse(timeOfDayParts[0]);
    final minute = int.parse(timeOfDayParts[1]);
    final isPM = timeParts[1].toLowerCase() == 'pm';

    return TimeOfDay(
      hour: isPM ? (hour == 12 ? 12 : hour + 12) : (hour == 12 ? 0 : hour),
      minute: minute,
    );
  }

  void _showParticipantDialog() {
    showDialog(
      context: context,
      builder: (context) => ParticipantDialog(
        selectedParticipants: _selectedParticipants,
        clubId: _selectedClub?.id ?? 0,
      ),
    ).then((result) {
      if (result != null) {
        setState(() {
          _selectedParticipants = List<ClubMemberProfile>.from(result);
        });
        _validateForm();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('이벤트 생성'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: '이벤트 제목',
                  hintText: '제목을 입력해주세요',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Club>(
                decoration: InputDecoration(
                  labelText: '모임 선택',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                value: _selectedClub,
                onChanged: (Club? value) {
                  setState(() {
                    _selectedClub = value;
                    _selectedParticipants = []; // 클럽 변경 시 참여자 초기화
                    _validateForm();
                  });
                },
                items: _clubs.map<DropdownMenuItem<Club>>((Club club) {
                  return DropdownMenuItem<Club>(
                    value: club,
                    child: Text(club.name),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _showLocationSearchDialog,
                child: AbsorbPointer(
                  child: TextField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      labelText: '장소',
                      hintText: '장소를 추가해주세요',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      prefixIcon: const Icon(Icons.location_on),
                    ),
                  ),
                ),
              ),
              if (_selectedLocation != null) const SizedBox(height: 16),
              if (_selectedLocation != null)
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _selectedLocation!,
                      zoom: 14.0,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('selected-location'),
                        position: _selectedLocation!,
                      ),
                    },
                  ),
                ),
              const SizedBox(height: 16),
              const Text('시간', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectDate(context, true),
                      child: AbsorbPointer(
                        child: TextField(
                          controller: _startDateController,
                          decoration: InputDecoration(
                            labelText: '시작 날짜',
                            hintText: '날짜 선택',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            prefixIcon: const Icon(Icons.calendar_today),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectTime(context, true),
                      child: AbsorbPointer(
                        child: TextField(
                          controller: _startTimeController,
                          decoration: InputDecoration(
                            labelText: '시작 시간',
                            hintText: '시간 선택',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            prefixIcon: const Icon(Icons.access_time),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectDate(context, false),
                      child: AbsorbPointer(
                        child: TextField(
                          controller: _endDateController,
                          decoration: InputDecoration(
                            labelText: '종료 날짜',
                            hintText: '날짜 선택',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            prefixIcon: const Icon(Icons.calendar_today),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('참여자', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _selectedClub != null ? _showParticipantDialog : null, // 클럽이 선택되지 않았으면 비활성화
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: _selectedClub != null ? Colors.grey : Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8.0),
                    color: _selectedClub != null ? Colors.white : Colors.grey[200],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_add, color: _selectedClub != null ? Colors.grey : Colors.grey[300]),
                      const SizedBox(width: 8),
                      Text(
                        _selectedParticipants.isEmpty
                            ? '+ 참여자 추가'
                            : _selectedParticipants.map((p) => p.name).join(', '),
                        style: const TextStyle(color: Colors.black),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('게임모드', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<GameMode>(
                decoration: const InputDecoration(
                  labelText: '게임모드',
                  border: OutlineInputBorder(),
                ),
                value: _selectedGameMode, // value를 GameMode 타입으로 설정
                onChanged: (newValue) {
                  setState(() {
                    _selectedGameMode = newValue!;
                    _validateForm();
                  });
                },
                items: GameMode.values.map((mode) {
                  return DropdownMenuItem<GameMode>(
                    value: mode,
                    child: Text(
                      mode == GameMode.STROKE ? '스트로크' : mode.toString(),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: _isButtonEnabled
                      ? () {
                    final DateTime startDate = _startDateController.text.isNotEmpty
                        ? DateTime.parse(_startDateController.text)
                        : DateTime.now(); // 기본값: 오늘 날짜

                    final TimeOfDay startTime = _startTimeController.text.isNotEmpty
                        ? _parseTimeOfDay(_startTimeController.text)
                        : TimeOfDay.now(); // 기본값: 현재 시간

                    final DateTime startDateTime = _convertToDateTime(startDate, startTime);
                    final DateTime endDateTime = _endDateController.text.isNotEmpty
                        ? _convertToDateTime(
                        DateTime.parse(_endDateController.text), _fixedTime)
                        : _convertToDateTime(startDate, _fixedTime); // 기본값: 당일 23:59

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EventsCreate2(
                          title: _titleController.text,
                          selectedClub: _selectedClub!,
                          selectedLocation: _selectedLocation!,
                          selectedSite: _site,
                          startDate: startDateTime,
                          endDate: endDateTime,
                          selectedParticipants: _selectedParticipants,
                          selectedGameMode: _selectedGameMode!,
                        ),
                      ),
                    );
                  }
                      : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('다음'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
