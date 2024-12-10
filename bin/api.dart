import 'dart:convert';
import 'package:bcrypt/bcrypt.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;


void main() async {
  final db = await mongo.Db.create(
      'mongodb+srv://anuptwri007:UntUz0k7iDUnpOvx@cluster0.pmzek.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0');

  await db.open();
  print('Connected to MongoDB');
  final usersCollection = db.collection('users');
  final movieCollection = db.collection('movies');
  final hallCollection = db.collection('hall');


  final router = Router();


  router.post('/signup', (Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body);

    final email = data['email'];
    final password = data['password'];
    final username = data['username'];
    final phone = data['phone'];
    final photo = data['photo'];
    final address = data['address'];
    final dob = data['dob'];

    // Check if the user already exists
    final existingUser = await usersCollection.findOne(mongo.where.eq('email', email));
    if (existingUser != null) {
      return Response(400, body: jsonEncode({'message': 'User already exists'}));
    }

    // Hash the password before saving it
    final hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());

    // Create a new user document
    final user = {
      'email': email,
      'password': hashedPassword,
      'username': username,
      'photo': photo,
      'address': address,
      'dob': dob,
      'phone': phone,
    };
    await usersCollection.insert(user);

    return Response(201, body: jsonEncode({'message': 'User created successfully',body: jsonEncode({
      'message': 'Login successful',
      'user': {
        'email': user['email'],
        'username': user['username'],
        'photo': user['photo'],
        'address': user['address'],
        'dob': user['dob'],
        'phone': user['phone'],
      }
    })}));
  });
  router.post('/login', (Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body);

    final email = data['email'];
    final password = data['password'];

    // Ensure the DB is open before making any operations
    await db.open();

    try {
      // Fetch user from MongoDB
      final user = await usersCollection.findOne(where.eq('email', email));
      if (user == null) {
        return Response(400, body: jsonEncode({'message': 'User not found'}));
      }

      // Check if the password matches
      final isPasswordValid = BCrypt.checkpw(password, user['password']);
      if (!isPasswordValid) {
        return Response(400, body: jsonEncode({'message': 'Invalid password'}));
      }

      // Return all user details if login is successful
      return Response(200, body: jsonEncode({
        'message': 'Login successful',
        'user': {
          'email': user['email'],
          'username': user['username'],
          // 'photo': user['photo'],
          'address': user['address'],
          'dob': user['dob'],
          'phone': user['phone'],
        }
      }));
    } catch (e) {
      // Handle any error and return internal server error
      return Response.internalServerError(body: jsonEncode({'message': 'An error occurred', 'error': e.toString()}));
    } finally {
      // Close the DB connection after the operation
      await db.close();
    }
  });
  router.post('/add-movie', (Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body);

    final photo = data['photo'];
    final title = data['title'];
    final description = data['description'];
    final director = data['director'];
    final language = data['language'];
    final status = data['status'];

    final format = List<String>.from(data['format'] ?? []);
    final genre = List<String>.from(data['genre'] ?? []);
    final cast = List<String>.from(data['cast'] ?? []);
    final date = List<String>.from(data['date'] ?? []);

    final dateTime = List<Map<String, String>>.from(
      (data['dateTime'] ?? []).map((item) {
        if (item is Map<String, dynamic>) {
          final date = item['date']?.toString() ?? '';
          final time = item['time']?.toString() ?? '';
          return {'date': date, 'time': time};
        } else {
          throw FormatException('Invalid dateTime format');
        }
      }),
    );

    final releaseDate = data['releaseDate'];

    final movie = {
      'photo': photo,
      'title': title,
      'description': description,
      'director': director,
      'language': language,
      'format': format,
      'genre': genre,
      'cast': cast,
      'date': date,
      'dateTime': dateTime,
      'releaseDate': releaseDate,
      'status': status,
    };

    await movieCollection.insert(movie);

    return Response(201, body: jsonEncode({'message': 'Movie created successfully'}));
  });
  router.post('/add-hall', (Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);

      // Validate required fields
      if (data['name'] == null || data['name'].toString().trim().isEmpty) {
        return Response(400, body: jsonEncode({'error': 'Name is required'}));
      }

      if (data['location'] == null || data['location'].toString().trim().isEmpty) {
        return Response(400, body: jsonEncode({'error': 'Location is required'}));
      }

      if (data['capacity'] == null || int.tryParse(data['capacity'].toString()) == null) {
        return Response(400, body: jsonEncode({'error': 'Capacity must be a valid number'}));
      }

      if (data['audi'] == null || !(data['audi'] is List)) {
        return Response(400, body: jsonEncode({'error': 'Audi must be a valid list'}));
      }

      // Validate Audi list
      final audi = List<Map<String, String>>.from(
        (data['audi']).map((item) {
          if (item is Map<String, dynamic>) {
            final name = item['name']?.toString()?.trim() ?? '';
            final capacity = item['capacity']?.toString()?.trim() ?? '';

            if (name.isEmpty) {
              throw FormatException('Audi name is required');
            }

            if (capacity.isEmpty || int.tryParse(capacity) == null) {
              throw FormatException('Audi capacity must be a valid number');
            }

            return {'name': name, 'capacity': capacity};
          } else {
            throw FormatException('Invalid Audi format');
          }
        }),
      );

      final hall = {
        'name': data['name'].toString().trim(),
        'location': data['location'].toString().trim(),
        'capacity': int.parse(data['capacity'].toString()),
        'audi': audi,
      };

      // Insert into the database
      await hallCollection.insert(hall);

      return Response(201, body: jsonEncode({'message': 'Hall created successfully'}));
    } catch (e) {
      // Handle validation or unexpected errors
      return Response(400, body: jsonEncode({'error': e.toString()}));
    }
  });
  router.post('/book-seats', (Request request) async {
    try {

      final body = await request.readAsString();
      final data = jsonDecode(body);

      final userId = data['userId'];
      final hallId = data['hallId'];
      final audiName = data['audiName'];
      final bookedSeats = List<String>.from(data['bookedSeats'] ?? []);
      if (userId == null || hallId == null || audiName == null || bookedSeats.isEmpty) {
        return Response(400, body: jsonEncode({'error': 'Invalid request body'}));
      }

      final hall = await hallCollection.findOne(where.eq('_id', ObjectId.fromHexString(hallId)));
      if (hall == null) {
        return Response(404, body: jsonEncode({'error': 'Hall not found'}));
      }

      final audi = (hall['audi'] as List).firstWhere(
            (a) => a['name'] == audiName,
        orElse: () => null,
      );
      if (audi == null) {
        return Response(404, body: jsonEncode({'error': 'Audi not found in the specified hall'}));
      }

      final updateResult = await usersCollection.update(
        where.eq('_id', ObjectId.fromHexString(userId)),
        modify.push('bookings', {
          'hallId': hallId,
          'audiName': audiName,
          'bookedSeats': bookedSeats,
        }),
      );

      if (updateResult['nModified'] == 0) {
        return Response(404, body: jsonEncode({'error': 'User not found'}));
      }

      return Response(200, body: jsonEncode({'message': 'Seats booked successfully'}));
    } catch (e) {

      return Response.internalServerError(
        body: jsonEncode({'error': 'An error occurred', 'details': e.toString()}),
      );
    }
  });




  Future<Response> getUsers(Request request) async {

    await db.open();

    try {

      final users = await usersCollection.find().toList();


      return Response.ok(jsonEncode(users), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: 'Error fetching users: $e');
    } finally {
      await db.close();
    }
  }
  router.get('/movie', (Request request) async {
    // await db.open();
    final queryParams = request.url.queryParameters;
    final filterDate = queryParams['date'];
    final filterStatus = queryParams['status'];

    Map<String, dynamic> query = {};

    if (filterStatus != null) {
      query['status'] = filterStatus;
    }


    if (filterDate != null) {
      query['dateTime'] = {
        '\$elemMatch': {'date': filterDate}
      };
    }

    // Fetch movies based on the constructed query
    final filteredMovies = await movieCollection.find(query).toList();

    if (filteredMovies.isEmpty) {
      // Return a 404 response if no movies are found based on the filters
      return Response(404, body: jsonEncode({'message': 'No movies found for the given filters'}));
    }

    // If filterDate is applied, extract the times for the given date
    if (filterDate != null) {
      final filteredTimes = filteredMovies.map((movie) {
        final times = movie['dateTime']
            .where((entry) => entry['date'] == filterDate)
            .map((entry) => entry['time'])
            .toList();

        return {
          'title': movie['title'],
          'times': times,
          'releaseDate': movie['releaseDate'],
        };
      }).toList();

      return Response(200, body: jsonEncode(filteredTimes));
    }

    // If no filterDate is applied, return the full movie data
    return Response(200, body: jsonEncode(filteredMovies));
  });
  router.get('/get-halls', (Request request) async {
    try {

      final halls = await hallCollection.find().toList();
      final response = halls.map((hall) {
        return {
          'id': hall['_id']?.toHexString(),
          'name': hall['name'],
          'location': hall['location'],
          'capacity': hall['capacity'],
          'audi': hall['audi'],
        };
      }).toList();

      return Response.ok(
        jsonEncode({'halls': response}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      // Handle errors
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to fetch halls: ${e.toString()}'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });
  router.get('/users', getUsers);

  final handler = const Pipeline().addMiddleware(logRequests()).addHandler(router);
  final server = await io.serve(handler, '0.0.0.0', 8080);
  print('Server listening at http://${server.address.host}:${server.port}');
}
